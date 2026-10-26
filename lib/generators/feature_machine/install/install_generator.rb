require "rails/generators"

module FeatureMachine
  module Generators
    # rails g feature_machine:install
    #
    # Writes config/initializers/feature_machine.rb with every knob in
    # FeatureMachine::Configuration, set to its default or commented out, and
    # says what to run next. Migrations come from the engine's own
    # install:migrations task so a host can re-run it after upgrades.
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates config/initializers/feature_machine.rb for the feature_machine engine."

      def copy_initializer
        template "initializer.rb", "config/initializers/feature_machine.rb"
      end

      def show_next_steps
        say <<~MSG

          feature_machine is configured in config/initializers/feature_machine.rb.
          Next:
            bin/rails feature_machine:install:migrations
            bin/rails db:migrate
          Then set current_user, admin and authenticate_api for your app.
        MSG
      end
    end
  end
end
