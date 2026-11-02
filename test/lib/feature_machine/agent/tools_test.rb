# Plain Minitest against a throwaway checkout; no model, no network.
require "minitest/autorun"
require "tmpdir"
require_relative "../../../../lib/feature_machine/agent/config"
require_relative "../../../../lib/feature_machine/agent/tools"

class FeatureMachine::Agent::ToolsTest < Minitest::Test
  Tools = FeatureMachine::Agent::Tools

  def setup
    @root = Dir.mktmpdir
    Dir.mkdir(File.join(@root, ".git"))
    File.write(File.join(@root, "a.rb"), "puts 1\n")
    @config = FeatureMachine::Agent::Config.new(
      app_url: "http://localhost:3000", token: "t", checkout: @root,
      test_command: "echo ran", plan_model: nil, implement_model: nil, max_steps: 5
    )
  end

  def teardown = FileUtils.remove_entry(@root)

  def test_reads_and_writes_inside_the_checkout
    assert_equal "puts 1\n", Tools::ReadFile.new(@config).execute(path: "a.rb")
    Tools::WriteFile.new(@config).execute(path: "b.rb", content: "x")
    assert_equal "x", File.read(File.join(@root, "b.rb"))
  end

  def test_refuses_paths_outside_the_checkout
    assert_match(/outside the checkout/, Tools::ReadFile.new(@config).execute(path: "../../etc/passwd")["error"])
    assert_match(/outside the checkout/, Tools::WriteFile.new(@config).execute(path: "/tmp/fm-escape", content: "x")["error"])
    refute File.exist?("/tmp/fm-escape")
  end

  def test_refuses_symlinks_out_of_the_checkout
    File.symlink("/etc", File.join(@root, "etc"))
    assert_match(/outside the checkout/, Tools::ReadFile.new(@config).execute(path: "etc/hosts")["error"])
  end

  def test_runs_the_test_command_without_a_shell
    result = Tools::RunTests.new(@config).execute(paths: [ "a.rb" ])
    assert_equal 0, result["exit_status"]
    assert_equal "ran #{File.realpath(@root)}/a.rb\n", result["output"]
  end

  def test_run_tests_scopes_paths_too
    assert_match(/outside the checkout/, Tools::RunTests.new(@config).execute(paths: [ "../x_test.rb" ])["error"])
  end

  def test_only_opening_a_pull_request_needs_approval
    assert Tools::OpenPullRequest.new(@config).requires_approval?
    refute Tools::ALL.reject { |t| t == Tools::OpenPullRequest }.any?(&:requires_approval?)
    assert_equal 4, Tools.for(@config).size
  end

  class StubJudge
    attr_reader :seen
    def initialize(pass) = @pass = pass
    def call(**args) = (@seen = args) && FeatureMachine::Agent::Judge::Verdict.new(pass: @pass, reasons: [ "because" ])
  end

  def git_checkout
    system("git", "init", "-q", "-b", "feature", @root, exception: true)
    # CI runners have no global git identity; the tool's own commit needs one.
    system("git", "-C", @root, "config", "user.name", "t", exception: true)
    system("git", "-C", @root, "config", "user.email", "t@t", exception: true)
    system("git", "-C", @root, "commit", "-q", "--allow-empty", "-m", "base", exception: true)
    File.write(File.join(@root, "new.rb"), "puts 2\n")
  end

  def commits = `git -C #{@root} rev-list --count HEAD`.to_i

  def test_a_rejected_change_is_never_committed_or_pushed
    git_checkout
    judge = StubJudge.new(false)
    result = Tools::OpenPullRequest.new(@config, judge: judge, criteria: ->(id) { id == 7 ? [ "adds new.rb" ] : [] }).execute(title: "t", body: "b", work_item_id: 7)

    assert_equal "judge rejected the change", result["error"]
    assert_equal [ "because" ], result["reasons"]
    assert_equal [ "adds new.rb" ], judge.seen[:criteria]
    assert_match(/\+puts 2/, judge.seen[:diff], "untracked files reach the judge")
    assert_equal 0, judge.seen[:tests]["exit_status"]
    assert_equal 1, commits
  end

  def test_a_passing_change_is_committed_before_the_push
    git_checkout
    result = Tools::OpenPullRequest.new(@config, judge: StubJudge.new(true), criteria: ->(_) { [ "adds new.rb" ] }).execute(title: "Add new.rb", body: "b", work_item_id: 7)

    refute_equal 0, result["exit_status"], "no origin, so the push fails and gh never runs"
    assert_equal 2, commits
    assert_equal "Add new.rb", `git -C #{@root} log -1 --format=%s`.strip
  end

  def test_an_item_without_criteria_never_reaches_the_judge
    git_checkout
    judge = StubJudge.new(true)
    result = Tools::OpenPullRequest.new(@config, judge: judge, criteria: ->(_) { [] }).execute(title: "t", body: "b", work_item_id: 7)

    assert_equal "work item 7 has no acceptance criteria", result["error"]
    assert_nil judge.seen
    assert_equal 1, commits
  end

  def test_the_model_cannot_supply_its_own_criteria
    properties = Tools::OpenPullRequest.new(@config, judge: StubJudge.new(true), criteria: ->(_) { [] }).parameters_schema.transform_keys(&:to_s).fetch("properties")
    assert_equal %w[body title work_item_id], properties.keys.map(&:to_s).sort
  end
end
