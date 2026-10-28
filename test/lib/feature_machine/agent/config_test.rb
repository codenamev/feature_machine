# Plain Minitest: the agent runs on the developer's machine with no host app,
# so its config must load without Rails or a database.
require "minitest/autorun"
require "tmpdir"
require_relative "../../../../lib/feature_machine/agent/config"

class FeatureMachine::Agent::ConfigTest < Minitest::Test
  Config = FeatureMachine::Agent::Config

  def setup
    @dir = Dir.mktmpdir
    Dir.mkdir(File.join(@dir, ".git"))
    @env = { "FEATURE_MACHINE_TOKEN" => "tok" }
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def write_file(body)
    File.write(File.join(@dir, Config::FILE), body)
  end

  def test_file_then_env_then_flags
    write_file("app_url: https://file.example\nmax_steps: 10\nplan_model: cheap\n")
    config = Config.load(checkout: @dir, env: @env.merge("FEATURE_MACHINE_APP_URL" => "https://env.example"),
                         flags: { max_steps: 5 })

    assert_equal "https://env.example", config.app_url
    assert_equal 5, config.max_steps
    assert_equal "cheap", config.implement_model, "implement_model falls back to plan_model"
    assert_equal "bin/rails test", config.test_command
  end

  def test_token_in_file_is_refused
    write_file("app_url: https://a.example\ntoken: leaked\n")
    error = assert_raises(Config::Invalid) { Config.load(checkout: @dir, env: @env) }
    assert_match(/FEATURE_MACHINE_TOKEN/, error.message)
  end

  def test_missing_token_and_app_url
    assert_raises(Config::Invalid) { Config.load(checkout: @dir, env: {}, flags: { app_url: "https://a.example" }) }
    assert_raises(Config::Invalid) { Config.load(checkout: @dir, env: @env) }
  end

  def test_checkout_must_be_a_git_repo
    Dir.rmdir(File.join(@dir, ".git"))
    assert_raises(Config::Invalid) { Config.load(checkout: @dir, env: @env, flags: { app_url: "https://a.example" }) }
  end

  def test_rejects_non_http_url_and_zero_steps
    assert_raises(Config::Invalid) { Config.load(checkout: @dir, env: @env, flags: { app_url: "file:///etc" }) }
    assert_raises(Config::Invalid) do
      Config.load(checkout: @dir, env: @env, flags: { app_url: "https://a.example", max_steps: 0 })
    end
  end
end
