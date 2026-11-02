module FeatureMachine
  # Who is asking, by the host's own answer (config.current_user), never by a
  # current_user method the host may not define. Pages need a signed-in user:
  # when the host's own filters let a signed-out request through, it goes to
  # config.sign_in_path, or gets a 401 if the host has none.
  module CurrentUser
    extend ActiveSupport::Concern

    included do
      helper_method :feature_machine_user
    end

    private

    def feature_machine_user
      return @feature_machine_user if defined?(@feature_machine_user)

      @feature_machine_user = FeatureMachine.config.user_for(request)
    end

    def require_feature_machine_user
      return if feature_machine_user

      path = FeatureMachine.config.sign_in_path&.call(self)
      path ? redirect_to(path) : head(:unauthorized)
    end
  end
end
