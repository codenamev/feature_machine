require "ruby_llm"

module FeatureMachine
  module Agent
    # The host app's maintainer MCP server, scoped to the three work-item
    # tools the agent needs. Writes back to the host pause for approval.
    class Host < RubyLLM::MCP
      # Not `config`: that name is RubyLLM::MCP#config, the RubyLLM settings
      # its HTTP transport reads, and an input of the same name replaces it.
      inputs :settings

      # A lambda, not a block: RubyLLM::MCP.url takes a value and ignores a
      # block, and a Proc value is resolved per instance, where settings exist.
      url -> { "#{settings.app_url.chomp('/')}/mcp" }
      bearer_token { settings.token }
      only :list_work_items, :get_work_item, :update_work_item
      requires_approval :update_work_item
    end
  end
end
