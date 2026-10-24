module FeatureMachine
  # The engine's Rails hook. For now it only installs the two auth middlewares
  # on the host's stack once its initializers have run. Both are no-ops until
  # configured (Bearer without `authenticate_api`, Session with
  # `session_auth = false`), so installing is unconditional and tests can flip
  # the configuration without rebuilding the stack.
  #
  # The models, controllers, views, jobs, services and prompts live in the
  # engine's app/ (phase 5b). It is still not isolated: routes stay in the
  # host's config/routes.rb, and the host keeps its overrides and
  # app/tools/mcp_tools/feature_machine. isolate_namespace and the engine's own
  # routes come later.
  class Engine < ::Rails::Engine
    initializer "feature_machine.auth_middleware", after: :load_config_initializers do |app|
      app.middleware.use FeatureMachine::Auth::Bearer
      app.middleware.use FeatureMachine::Auth::Session
    end

    # RubyLLM::Prompt only looks in Rails.root/app/prompts by default. The host
    # root stays first, so a host app can override any engine prompt.
    initializer "feature_machine.prompts" do
      RubyLLM::Prompt.roots << root.join("app/prompts")
    end
  end
end
