require "rails/generators"

module FeatureMachine
  module Generators
    # rails g feature_machine:install
    #
    # Writes config/initializers/feature_machine.rb with every knob in
    # FeatureMachine::Configuration, set to its default or commented out, and
    # says what to run next. Also draws the engine's routes into
    # config/routes.rb. Migrations come from the engine's own
    # install:migrations task so a host can re-run it after upgrades.
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates config/initializers/feature_machine.rb for the feature_machine engine."

      def copy_initializer
        template "initializer.rb", "config/initializers/feature_machine.rb"
      end

      # Rails' authentication generator redirects to root_url after sign-in,
      # and a fresh `rails new` has no root route, so the first login 500s.
      # Not the engine's bug, but every first-time installer hits it.
      def check_root_route
        routes = File.join(destination_root, "config/routes.rb")
        return unless rails_authentication? && File.exist?(routes)
        return if File.read(routes).match?(/^\s*root\b/)

        say_status :warn, "config/routes.rb has no root route; Rails' sign-in redirects to root_url and will 500 until you add one", :yellow
      end

      # The engine's routes are drawn into the host's route set (see
      # FeatureMachine::Routes), so the generator adds the four macro calls
      # rather than a mount line. Skipped if the host already calls the macro.
      def add_routes
        routes = File.join(destination_root, "config/routes.rb")
        unless File.exist?(routes)
          say_status :skip, "config/routes.rb not found; add the feature_machine_routes calls yourself", :yellow
          return
        end
        return say_status(:identical, "feature_machine_routes in config/routes.rb", :blue) if File.read(routes).include?("feature_machine_routes")

        route <<~RUBY
          feature_machine_routes :web
          namespace :admin do
            feature_machine_routes :admin
          end
          namespace :api, defaults: { format: :json } do
            feature_machine_routes :api
          end
          feature_machine_routes :mcp
        RUBY
      end

      def show_next_steps
        say <<~MSG

          feature_machine is configured in config/initializers/feature_machine.rb.
          Next:
            bin/rails feature_machine:install:migrations
            bin/rails db:migrate
          Then check current_user and admin, and set authenticate_api for your app.
          Signed-in users get /feature-requests, /bug-reports and /roadmap;
          admins get /admin/triage and /admin/work_items; agents get /api and /mcp.
        MSG
      end

      private
        # `bin/rails generate authentication` writes app/models/session.rb and
        # a signed session_id cookie; that's the convention we key off.
        def rails_authentication?
          File.exist?(File.join(destination_root, "app/models/session.rb"))
        end
    end
  end
end
