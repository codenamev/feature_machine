require "fileutils"
require "open3"
require "shellwords"
require "ruby_llm"
require_relative "host"
require_relative "judge"

module FeatureMachine
  module Agent
    # The agent's hands in the local checkout. Every path resolves inside
    # the checkout (symlinks included), commands run without a shell, and
    # opening a pull request pauses for approval.
    module Tools
      class OutsideCheckout < StandardError; end

      OUTPUT_LINES = 200
      LISTED_FILES = 500

      class Base < RubyLLM::Tool
        # "read_file", not "feature_machine--agent--tools--read_file": the
        # name a person sees at the approval prompt.
        def self.tool_name = RubyLLM::Support::Utils.underscore(name.split("::").last)

        def initialize(config)
          super()
          @root = File.realpath(config.checkout)
          @config = config
        end

        private

        # Checks the path as written, then again after following symlinks
        # from the nearest existing ancestor.
        def resolve(path)
          full = File.expand_path(path, @root)
          ensure_inside!(path, full)
          existing = full
          existing = File.dirname(existing) until File.exist?(existing)
          real = File.join(File.realpath(existing), full.delete_prefix(existing))
          ensure_inside!(path, real)
          real.chomp("/")
        end

        def ensure_inside!(path, candidate)
          return if candidate == @root || candidate.start_with?("#{@root}/")

          raise OutsideCheckout, "#{path} is outside the checkout"
        end

        def run(*argv)
          output, status = Open3.capture2e(*argv, chdir: @root)
          { "exit_status" => status.exitstatus, "output" => output.lines.last(OUTPUT_LINES).join }
        end
      end

      # Without a listing the model can only guess paths, and a fresh app has
      # none of the ones it guesses.
      class ListFiles < Base
        description "Lists the files in the checkout, or under one directory of it."
        parameter :path, description: "Directory relative to the checkout root; omit for all of it", required: false

        def execute(path: nil)
          dir = path.to_s.empty? ? @root : resolve(path)
          relative = dir.delete_prefix(@root).delete_prefix("/")
          files = tracked(relative) || Dir.glob("**/*", base: dir).reject { |f| File.directory?(File.join(dir, f)) }
                                          .map { |f| relative.empty? ? f : File.join(relative, f) }
          return "(no files under #{path})" if files.empty?

          listing = files.sort.first(LISTED_FILES)
          listing << "(#{files.size - LISTED_FILES} more; list a subdirectory)" if files.size > LISTED_FILES
          listing.join("\n")
        rescue OutsideCheckout => e
          { "error" => e.message }
        end

        private

        # Tracked and untracked-but-not-ignored files, so log/ and tmp/ stay out.
        def tracked(relative)
          output, status = Open3.capture2("git", "ls-files", "--cached", "--others", "--exclude-standard",
                                          "--", relative.empty? ? "." : relative, chdir: @root, err: File::NULL)
          output.lines(chomp: true).uniq if status.success?
        end
      end

      class ReadFile < Base
        description "Reads a file in the checkout."
        parameter :path, description: "Path relative to the checkout root"

        def execute(path:)
          File.read(resolve(path))
        rescue OutsideCheckout, Errno::ENOENT, Errno::EISDIR => e
          { "error" => e.message }
        end
      end

      class WriteFile < Base
        description "Writes a file in the checkout, replacing its contents."
        parameter :path, description: "Path relative to the checkout root"
        parameter :content, description: "The full new contents"

        def execute(path:, content:)
          full = resolve(path)
          FileUtils.mkdir_p(File.dirname(full))
          File.write(full, content)
          { "written" => path, "bytes" => content.bytesize }
        rescue OutsideCheckout, Errno::EISDIR => e
          { "error" => e.message }
        end
      end

      class RunTests < Base
        description "Runs the host's test command, optionally on given files."
        parameter :paths, type: :array, description: "Test files to run; omit for the whole suite", required: false

        def execute(paths: nil)
          files = Array(paths).map { |p| resolve(p) }
          progress "Running #{files.empty? ? 'the suite' : "#{files.size} test file(s)"}"
          result = run(*Shellwords.split(@config.test_command), *files)
          progress "Tests exited #{result['exit_status']}"
          result
        rescue OutsideCheckout => e
          { "error" => e.message }
        end
      end

      # Stages the agent's changes, runs the whole suite, and asks the Judge.
      # Only a passing verdict commits, pushes, and opens the pull request.
      class OpenPullRequest < Base
        description "Runs the suite, has the judge check the change against the criteria, " \
                    "then commits, pushes, and opens a pull request. Needs approval."
        parameter :title, description: "Pull request title, also the commit message"
        parameter :body, description: "Pull request description"
        parameter :work_item_id, type: :integer, description: "The work item this change fulfils"
        requires_approval

        # Criteria come from the host, never from the model's arguments, so
        # the agent cannot grade itself against criteria it wrote.
        def self.host_criteria(config)
          host = Host.new(settings: config)
          lambda do |id|
            result = host.call(:get_work_item, id: id)
            raise result.text if result.error?

            JSON.parse(result.text)["acceptance_criteria"].to_s
                .lines.map { |line| line.sub(/\A\s*(?:[-*]|\d+[.)])\s*/, "").strip }.reject(&:empty?)
          end
        end

        def initialize(config, judge: Judge.new(model: config.plan_model), criteria: self.class.host_criteria(config))
          super(config)
          @judge = judge
          @criteria = criteria
        end

        def execute(title:, body:, work_item_id:)
          criteria = @criteria.call(work_item_id)
          return { "error" => "work item #{work_item_id} has no acceptance criteria" } if criteria.empty?

          branch = run("git", "rev-parse", "--abbrev-ref", "HEAD")["output"].strip
          return { "error" => "refusing to open a pull request from a detached HEAD" } if branch == "HEAD"

          # Never commit to the default branch: move the work onto its own.
          # -C, not -c: a rerun after a failed push reuses the branch name.
          if protected_branches.include?(branch)
            branch = "feature-machine/work-item-#{work_item_id}"
            switched = run("git", "switch", "-C", branch)
            return switched unless switched["exit_status"].zero?
          end

          run("git", "add", "-A")
          diff, = Open3.capture2("git", "diff", "--cached", "HEAD", chdir: @root) # whole diff, not the tail
          tests = run(*Shellwords.split(@config.test_command))
          verdict = @judge.call(criteria: criteria, diff: diff, tests: tests)
          return { "error" => "judge rejected the change", "reasons" => verdict.reasons } unless verdict.pass?

          committed = run("git", "commit", "-m", title)
          return committed unless committed["exit_status"].zero?

          pushed = run("git", "push", "-u", "origin", branch)
          return pushed unless pushed["exit_status"].zero?

          run("gh", "pr", "create", "--title", title, "--body", body, "--head", branch)
        end

        private

        # main, master, and whatever origin calls its default (develop, trunk).
        def protected_branches
          default = run("git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
          origin_default = default["output"].strip.delete_prefix("origin/") if default["exit_status"].zero?
          [ "main", "master", origin_default ].compact
        end
      end

      ALL = [ ListFiles, ReadFile, WriteFile, RunTests, OpenPullRequest ].freeze

      def self.for(config) = ALL.map { |tool| tool.new(config) }
    end
  end
end
