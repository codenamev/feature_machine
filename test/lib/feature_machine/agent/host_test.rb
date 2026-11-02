# Plain Minitest: declaration and settings only, no server is contacted.
require "minitest/autorun"
require "tmpdir"
require_relative "../../../../lib/feature_machine/agent/config"
require_relative "../../../../lib/feature_machine/agent/host"

class FeatureMachine::Agent::HostTest < Minitest::Test
  def test_is_an_mcp_server_scoped_to_work_item_tools
    assert_operator FeatureMachine::Agent::Host, :<, RubyLLM::MCP
    source = File.read(File.expand_path("../../../../lib/feature_machine/agent/host.rb", __dir__))
    assert_match(/only :list_work_items, :get_work_item, :update_work_item/, source)
    assert_match(/requires_approval :update_work_item/, source)
  end

  def test_points_at_the_apps_mcp_endpoint_with_the_maintainer_token
    Dir.mktmpdir do |dir|
      Dir.mkdir(File.join(dir, ".git"))
      config = FeatureMachine::Agent::Config.new(app_url: "https://app.example/", token: "tok", checkout: dir,
                                                 test_command: "true", plan_model: nil, implement_model: nil, max_steps: 1)
      host = FeatureMachine::Agent::Host.new(settings: config)
      assert_equal "https://app.example/mcp", host.send(:resolve, FeatureMachine::Agent::Host.url)
      assert_equal "tok", host.send(:resolve, FeatureMachine::Agent::Host.bearer_token)
    end
  end
end
