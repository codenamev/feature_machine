# Plain Minitest, like config_test: the CLI must boot without Rails.
require "minitest/autorun"
require "stringio"
require "tmpdir"
require_relative "../../../../lib/feature_machine/agent"

class FeatureMachine::Agent::CLITest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    Dir.mkdir(File.join(@dir, ".git"))
    @env = { "FEATURE_MACHINE_TOKEN" => "tok", "FEATURE_MACHINE_APP_URL" => "https://example.test" }
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def run_cli(*argv, env: @env)
    out = StringIO.new
    err = StringIO.new
    status = FeatureMachine::Agent::CLI.start(argv, out: out, err: err, env: env)
    [ status, out.string, err.string ]
  end

  def test_agent_loads_config_and_reports_it
    status, out, = run_cli("agent", "--checkout", @dir, "--max-steps", "5")
    assert_equal 0, status
    assert_includes out, "https://example.test -> #{@dir}"
    assert_includes out, "max_steps: 5"
  end

  def test_missing_token_is_a_usage_error
    status, _, err = run_cli("agent", "--checkout", @dir, env: { "FEATURE_MACHINE_APP_URL" => "https://example.test" })
    assert_equal 64, status
    assert_includes err, "FEATURE_MACHINE_TOKEN"
  end

  def test_token_flag_is_not_accepted
    status, _, err = run_cli("agent", "--checkout", @dir, "--token", "x")
    assert_equal 64, status
    assert_includes err, "--token"
  end

  def test_unknown_command
    status, _, err = run_cli("deploy")
    assert_equal 64, status
    assert_includes err, "unknown command: deploy"
  end

  def test_help
    status, out, = run_cli("--help")
    assert_equal 0, status
    assert_includes out, "usage: feature_machine agent"
  end
end
