# The engine's API controllers authenticate from the Rack env, never from the
# host's token model: FeatureMachine::Auth::Bearer (or the host's own
# middleware) has already put a credential at FeatureMachine::ENV_KEY. The
# prose in 401/403 bodies comes from FeatureMachine.config.
#
# The parent is config.api_parent_controller (ActionController::API by
# default). A host base that already renders errors its own way (render_error,
# not-found and missing-parameter handling) keeps it; the fallbacks below only
# fill in what the parent lacks, so a fresh host's API works with no base of
# its own.
class Api::FeatureMachine::BaseController < FeatureMachine.config.api_parent_controller.constantize
  inherited_private = ->(name) { private_method_defined?(name) || method_defined?(name) }

  unless inherited_private.(:render_error)
    rescue_from ActiveRecord::RecordNotFound do
      render_error(status: :not_found, error: "Not found", code: "not_found",
                   resolution: "Verify the resource id belongs to the authenticated user.")
    end
    rescue_from ActionController::ParameterMissing do |exception|
      render_error(status: :bad_request, error: exception.message, code: "parameter_missing",
                   resolution: "Include the required parameter in the request body.")
    end
  end

  private

  # Engine-owned names: a host base's own current_user or current_credential
  # is left alone, and never stands in for the engine's.
  attr_reader :api_user, :api_credential

  unless inherited_private.(:render_error)
    def render_error(status:, error:, code:, resolution: nil, errors: nil)
      body = { error: error, code: code }
      body[:resolution] = resolution if resolution
      body[:errors] = errors if errors
      render json: body, status: status
    end
  end

  # Reads need `read`, writes need `write`; the work-item hand-off overrides
  # it with `maintainer`.
  unless inherited_private.(:required_scope)
    def required_scope
      request.get? || request.head? ? ::FeatureMachine::READ : ::FeatureMachine::WRITE
    end
  end

  def authenticate_user_with_token
    @api_credential = request.env[::FeatureMachine::ENV_KEY]
    @api_user = @api_credential&.user
    return render_unauthenticated unless @api_user
    return render_session_write_forbidden if session_credential? && !(request.get? || request.head?)

    enforce_scope
  end

  # The engine's rule, not the credential's: for `maintainer`, the host's admin
  # predicate must agree (FeatureMachine::Auth.allows?).
  def enforce_scope
    return if ::FeatureMachine::Auth.allows?(api_credential, required_scope)

    response.headers["WWW-Authenticate"] =
      %(Bearer realm="#{feature_machine_config.product_name}", error="insufficient_scope", scope="#{required_scope}")
    render_error(
      status: :forbidden,
      error: "Token lacks the #{required_scope} scope",
      code: "insufficient_scope",
      resolution: "This endpoint requires a token with the `#{required_scope}` scope.#{create_token_hint}"
    )
  end

  def render_unauthenticated
    config = feature_machine_config
    response.headers["WWW-Authenticate"] = [
      %(Bearer realm="#{config.product_name}", error="invalid_token", error_description="Missing or invalid bearer token."),
      (%(resource="#{config.protected_resource_url}") if config.protected_resource_url)
    ].compact.join(", ")

    resolution = [
      "Send Authorization: Bearer <token>.",
      ("Humans create tokens at #{config.token_help_url}." if config.token_help_url),
      ("See #{config.protected_resource_url} for protected-resource metadata." if config.protected_resource_url)
    ].compact.join(" ")
    render_error(status: :unauthorized, error: "Unauthorized", code: "unauthorized", resolution: resolution)
  end

  # A browser session may read through the API; writes take a bearer token,
  # so a cross-site form can never act on a signed-in user's behalf here.
  def render_session_write_forbidden
    render_error(
      status: :forbidden,
      error: "Writes need a bearer token",
      code: "session_write_forbidden",
      resolution: "This request is authenticated by your browser session, which the API accepts for reads only. Send Authorization: Bearer <token> to write.#{create_token_hint}"
    )
  end

  def session_credential?
    api_credential.respond_to?(:session?) && api_credential.session?
  end

  def create_token_hint
    feature_machine_config.token_help_url ? " Create one at #{feature_machine_config.token_help_url}." : ""
  end

  def feature_machine_config
    ::FeatureMachine.config
  end
end
