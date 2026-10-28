require "ruby_llm"

module FeatureMachine
  module Agent
    # The host app's maintainer MCP server, scoped to the three work-item
    # tools the agent needs. Writes back to the host pause for approval.
    class Host < RubyLLM::MCP
      inputs :config

      url { "#{config.app_url.chomp('/')}/mcp" }
      bearer_token { config.token }
      only :list_work_items, :get_work_item, :update_work_item
      requires_approval :update_work_item
    end
  end
end
