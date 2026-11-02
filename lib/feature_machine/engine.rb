module FeatureMachine
  # The engine's Rails hook: installs the two auth middlewares on the host's
  # stack once its initializers have run, and adds the engine's prompts to
  # RubyLLM's search path. Both middlewares are no-ops until configured
  # (Bearer without `authenticate_api`, Session with `session_auth = false`),
  # so installing is unconditional and tests can flip the configuration
  # without rebuilding the stack.
  #
  # Models, controllers, views, jobs, services, prompts and the MCP tools live
  # in the engine's app/. It is not isolated: its routes are drawn into the
  # host's own route set by the feature_machine_routes macro (see Routes), so
  # its pages use the host's unprefixed route helpers.
  class Engine < ::Rails::Engine
    # Without isolate_namespace the name would default to
    # "feature_machine_engine", and so would the install:migrations task.
    engine_name "feature_machine"

    # The engine ships its three migrations in db/migrate. A new host copies
    # them with `bin/rails feature_machine:install:migrations`. A host that already
    # has copies with the same class names gets all three skipped, and its
    # schema.rb doesn't change. Nothing adds the engine's path
    # to the host's migrations_paths, so they never run twice.
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
