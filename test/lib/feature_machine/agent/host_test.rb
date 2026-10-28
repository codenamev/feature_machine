# Plain Minitest: declaration only, no server is contacted.
require "minitest/autorun"
require_relative "../../../../lib/feature_machine/agent/config"
require_relative "../../../../lib/feature_machine/agent/host"

class FeatureMachine::Agent::HostTest < Minitest::Test
  def test_is_an_mcp_server_scoped_to_work_item_tools
    assert_operator FeatureMachine::Agent::Host, :<, RubyLLM::MCP
    source = File.read(File.expand_path("../../../../lib/feature_machine/agent/host.rb", __dir__))
    assert_match(/only :list_work_items, :get_work_item, :update_work_item/, source)
    assert_match(/requires_approval :update_work_item/, source)
  end
end
