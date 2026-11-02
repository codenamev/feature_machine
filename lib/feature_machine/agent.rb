require "json"
require "optparse"
require_relative "agent/config"

module FeatureMachine
  # The local coding agent. It runs on a developer's machine against a host
  # app's maintainer API and never loads Rails, so the engine itself does not
  # require this file; `require "feature_machine/agent"` opts in.
  module Agent
    # Outside Rails nobody calls RubyLLM.configure, so the agent reads each
    # provider's key from its conventional variable (openai_api_key from
    # OPENAI_API_KEY, and so on for every *_api_key RubyLLM knows). A key the
    # process already configured is left alone.
    def self.configure_providers(env = ENV)
      require "ruby_llm"
      RubyLLM.configure do |config|
        config.class.instance_methods.grep(/_api_key=\z/).each do |setter|
          name = setter.to_s.chomp("=")
          value = env[name.upcase]
          config.public_send(setter, value) if value && !value.empty? && config.public_send(name).nil?
        end
      end
    end

    class CLI
      USAGE = <<~TEXT.freeze
        usage: feature_machine agent [options]

        With no --work-item, lists the planned work items waiting to be picked up.
        With --work-item ID, works that item in the checkout: it plans, edits,
        runs the tests, and asks you before every write back to the app and
        before opening a pull request.

        The app URL and maintainer token come from FEATURE_MACHINE_APP_URL and
        FEATURE_MACHINE_TOKEN (the token is never a flag, so it stays out of
        shell history). Other settings may also live in .feature_machine.yml.
      TEXT

      def self.start(argv = ARGV, out: $stdout, err: $stderr, env: ENV, input: $stdin, queue: nil, fulfiller: nil)
        new(out: out, err: err, env: env, input: input, queue: queue, fulfiller: fulfiller).run(argv.dup)
      end

      def initialize(out:, err:, env:, input: $stdin, queue: nil, fulfiller: nil)
        @out = out
        @err = err
        @env = env
        @input = input
        @queue = queue || method(:planned_items)
        @fulfiller = fulfiller
      end

      def run(argv)
        command = argv.shift
        return usage(@out, 0) if command.nil? || %w[-h --help help].include?(command)
        return usage(@err, 64, "unknown command: #{command}") unless command == "agent"

        flags = parse(argv)
        return usage(@out, 0) if flags.delete("help")

        item_id = flags.delete("work_item")
        config = Config.load(flags: flags, env: @env)
        @out.puts "feature_machine agent: #{config.app_url} -> #{config.checkout}"
        @out.puts "  tests: #{config.test_command}, max_steps: #{config.max_steps}"
        item_id ? work(config, item_id) : list(config)
      rescue OptionParser::ParseError, Config::Invalid => e
        usage(@err, 64, e.message)
      end

      private

      # No --token flag: a token on the command line lands in shell history.
      def parse(argv)
        flags = {}
        OptionParser.new do |o|
          o.on("-h", "--help") { flags["help"] = true }
          o.on("--work-item ID", Integer) { |v| flags["work_item"] = v }
          o.on("--app-url URL") { |v| flags["app_url"] = v }
          o.on("--checkout DIR") { |v| flags["checkout"] = v }
          o.on("--test-command CMD") { |v| flags["test_command"] = v }
          o.on("--plan-model MODEL") { |v| flags["plan_model"] = v }
          o.on("--implement-model MODEL") { |v| flags["implement_model"] = v }
          o.on("--max-steps N", Integer) { |v| flags["max_steps"] = v }
        end.parse!(argv)
        raise OptionParser::InvalidArgument, argv.join(" ") unless argv.empty?

        flags
      end

      def list(config)
        items = @queue.call(config)
        if items.empty?
          @out.puts "No planned work items."
        else
          @out.puts "Planned work items:"
          items.each { |item| @out.puts "  ##{item["id"]}  #{item["title"]}" }
          @out.puts "Run again with --work-item ID to pick one up."
        end
        0
      rescue StandardError => e
        @err.puts "could not list work items from #{config.app_url}: #{e.message}"
        1
      end

      # Runs the Fulfiller, stopping at every approval to ask the person at
      # the keyboard. Approvals don't spend steps; max_steps covers the run.
      def work(config, item_id)
        return usage(@err, 64, "--plan-model is required to work an item") if config.plan_model.to_s.empty?

        fulfiller = @fulfiller || begin
          require_relative "agent/fulfiller"
          Agent.configure_providers(@env)
          Fulfiller
        end
        chat = fulfiller.chat(config: config)
        result = fulfiller.run(chat, item_id: item_id, max_steps: config.max_steps, implement_model: config.implement_model)
        steps = result.steps

        while result.status == :awaiting_approval
          result.pending.each { |call| decide(chat, call) }
          result = fulfiller.resume(chat, max_steps: config.max_steps - steps)
          steps += result.steps
        end

        report(result, steps)
      rescue RubyLLM::ConfigurationError, RubyLLM::ModelNotFoundError => e
        @err.puts "\nThe model isn't usable: #{e.message.lines.first.strip}"
        @err.puts "Set the provider's key (e.g. OPENAI_API_KEY) or pick another --plan-model."
        1
      rescue RubyLLM::MCP::Error => e
        @err.puts "\nCould not work with #{config.app_url}/mcp: #{e.message.lines.first.to_s.strip}"
        @err.puts "Check FEATURE_MACHINE_APP_URL, and that FEATURE_MACHINE_TOKEN is a maintainer token held by an admin."
        1
      rescue Faraday::Error => e
        # The MCP connect doesn't wrap a refused connection; the message names the host.
        @err.puts "\nNetwork error: #{e.message.lines.first.to_s.strip}"
        @err.puts "Check FEATURE_MACHINE_APP_URL and that the app is running."
        1
      end

      def decide(chat, call)
        @out.puts "\nThe agent wants to call #{call.name}:"
        @out.puts JSON.pretty_generate(call.arguments)
        @out.print "Allow it? [y/N] "
        answer = @input.gets.to_s.strip.downcase
        answer == "y" || answer == "yes" ? chat.approve(call) : chat.deny(call)
      end

      def report(result, steps)
        case result.status
        when :done
          @out.puts "\nDone in #{steps} steps."
          0
        when :step_limit
          @err.puts "\nStopped at max_steps (#{steps}). Raise --max-steps or rerun to continue."
          1
        else
          @err.puts "\nFailed after #{steps} steps: #{result.error&.message}"
          1
        end
      end

      # The pickup queue, read through the same MCP connection the agent works
      # through: list_work_items, with no model in the loop.
      def planned_items(config)
        require_relative "agent/host"
        begin
          result = Host.new(settings: config).call(:list_work_items)
        rescue RubyLLM::MCP::Error => e
          raise e unless e.code && "#{e.message} #{e.data}".match?(/tool not found/i)

          raise "#{e.message} (the app offers the work-item tools only to a maintainer token held by an admin)"
        end
        raise result.text.to_s if result.error?

        JSON.parse(result.text).fetch("work_items", [])
      end

      def usage(io, status, message = nil)
        io.puts message if message
        io.puts USAGE
        status
      end
    end
  end
end
