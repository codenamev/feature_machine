require "action_dispatch/routing/mapper"

module FeatureMachine
  # The engine's routes, drawn into the host's own route set rather than
  # mounted. The engine isn't isolated, so its
  # controllers and views use the host's unprefixed helpers
  # (feature_requests_path, admin_work_items_path); a mount would move those
  # onto an engine proxy. The host calls the macro once per scope, inside the
  # namespace that scope belongs to:
  #
  #   feature_machine_routes :web          # top level, before any catch-all
  #   namespace :admin do
  #     feature_machine_routes :admin
  #   end
  #   namespace :api, defaults: { format: :json } do
  #     feature_machine_routes :api
  #   end
  #
  # Paths, controllers and helper names match what the first host drew by
  # hand before the macro existed, so adopting it changes no URLs.
  module Routes
    SCOPES = %i[ web admin api ].freeze

    def feature_machine_routes(scope)
      case scope
      when :web
        resources :feature_requests, only: [ :index, :new, :create ], path: "feature-requests", controller: "feature_machine/feature_requests"
      when :admin
        resources :feature_requests, only: [ :update ], controller: "/feature_machine/admin/feature_requests"
        resources :work_items, controller: "/feature_machine/admin/work_items" do
          member { post :draft }
          resources :relations, only: [ :create, :destroy ], controller: "/feature_machine/admin/work_item_relations"
        end
      when :api
        resources :feature_requests, only: [ :index, :create ], controller: "feature_machine/feature_requests"
        resources :work_items, only: [ :index, :show, :update ], controller: "feature_machine/work_items"
      else
        raise ArgumentError, "feature_machine_routes scope must be one of #{SCOPES.inspect}, got #{scope.inspect}"
      end
    end
  end
end

ActionDispatch::Routing::Mapper.include(FeatureMachine::Routes)
