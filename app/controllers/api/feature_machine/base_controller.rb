# The engine's API controllers authenticate from the Rack env, never from the
# host's token model: FeatureMachine::Auth::Bearer (or the host's own
# middleware) has already put a credential at FeatureMachine::ENV_KEY. The
# error shape, rate-limit and link headers still come from the host's
# Api::BaseController; the prose in 401/403 bodies comes from
# FeatureMachine.config.
class Api::FeatureMachine::BaseController < Api::BaseController
  private

  def authenticate_user_with_token
    @current_credential = request.env[::FeatureMachine::ENV_KEY]
    @current_user = @current_credential&.user
    return render_unauthenticated unless @current_user
    return render_session_write_forbidden if session_credential? && !(request.get? || request.head?)

    enforce_scope
  end

  # The engine's rule, not the credential's: for `maintainer`, the host's admin
  # predicate must agree (FeatureMachine::Auth.allows?).
  def enforce_scope
    return if ::FeatureMachine::Auth.allows?(current_credential, required_scope)

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
    current_credential.respond_to?(:session?) && current_credential.session?
  end

  def create_token_hint
    feature_machine_config.token_help_url ? " Create one at #{feature_machine_config.token_help_url}." : ""
  end

  def feature_machine_config
    ::FeatureMachine.config
  end
end
