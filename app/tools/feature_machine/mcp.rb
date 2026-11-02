module FeatureMachine
  # The engine's MCP tools. `tools` is what any signed-up user's agent sees:
  # file and follow their own requests and bug reports, read the roadmap.
  # `maintainer_tools` exist only for a credential that may use them (they
  # are not advertised otherwise), and are the three the fulfilment agent
  # calls.
  #
  # FeatureMachine::McpController serves them at /mcp. A host that already
  # runs an MCP server adds FeatureMachine::Mcp.for(credential) to its own
  # tool list instead of drawing the engine's endpoint, and passes the
  # credential in server_context[:credential].
  module Mcp
    def self.tools
      [ ListFeatureRequests, RequestFeature, ListBugReports, ReportBug, ReadRoadmap ]
    end

    def self.maintainer_tools
      [ ListWorkItems, GetWorkItem, UpdateWorkItem ]
    end

    def self.for(credential)
      ::FeatureMachine::Auth.allows?(credential, ::FeatureMachine::MAINTAINER) ? tools + maintainer_tools : tools
    end
  end
end
