# Stateless MCP endpoint (streamable HTTP, JSON responses). Each POST is an
# independent JSON-RPC exchange. Users' agents file and follow their own
# requests; a maintainer token also gets the three work-item tools the
# fulfilment agent calls. Only bearer tokens count here: a browser session
# cookie is never an MCP credential, so no page can drive these tools.
class FeatureMachine::McpController < ActionController::API
  def handle
    result = server.handle_json(request.body.read)
    result.nil? ? head(:accepted) : render(json: result)
  end

  # Stateless: no server-initiated stream to offer on GET.
  def reject_get
    head :method_not_allowed
  end

  private

  def server
    MCP::Server.new(
      name: "feature_machine",
      title: FeatureMachine.config.product_name,
      version: FeatureMachine::VERSION,
      instructions: "Feature requests, bug reports and the roadmap for #{FeatureMachine.config.product_name}.",
      tools: FeatureMachine::Mcp.for(credential),
      server_context: { credential: credential }
    )
  end

  def credential
    return @credential if defined?(@credential)

    found = request.env[FeatureMachine::ENV_KEY]
    @credential = (found unless found.respond_to?(:session?) && found.session?)
  end
end
