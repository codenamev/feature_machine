# The engine's HTML controllers inherit the host's ApplicationController. The
# dummy stands in for it with the one thing they call: current_user, resolved
# through the engine's own config hook rather than a host auth concern.
class ApplicationController < ActionController::Base
  helper_method :current_user

  private

  def current_user
    @current_user ||= FeatureMachine.config.user_for(request)
  end
end
