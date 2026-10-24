module FeatureMachine
  # The engine's Rails hook. For now it only installs the two auth middlewares
  # on the host's stack once its initializers have run. Both are no-ops until
  # configured (Bearer without `authenticate_api`, Session with
  # `session_auth = false`), so installing is unconditional and tests can flip
  # the configuration without rebuilding the stack.
  #
  # Not isolated yet: the controllers, models and views still live in the
  # host's app/ under FeatureMachine:: and its routes in the host's
  # config/routes.rb. Phase 5b moves app/ in here; isolate_namespace and the
  # engine's own routes and middleware stack come with it.
  class Engine < ::Rails::Engine
    initializer "feature_machine.auth_middleware", after: :load_config_initializers do |app|
      app.middleware.use FeatureMachine::Auth::Bearer
      app.middleware.use FeatureMachine::Auth::Session
    end
  end
end
