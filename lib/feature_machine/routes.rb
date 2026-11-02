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
  #   feature_machine_routes :mcp          # POST /mcp, for agents
  #
  # Paths and helper names match what the first host drew by hand, so URLs
  # don't move. The macro now also draws bug reports, the roadmap, triage,
  # attachments and their APIs: a host that still draws any of those itself
  # must drop its own, or Rails refuses the duplicate route name at boot. A
  # host that already serves MCP skips :mcp and mounts FeatureMachine::Mcp's
  # tools in its own server instead.
  module Routes
    SCOPES = %i[ web admin api mcp ].freeze

    def feature_machine_routes(scope)
      case scope
      when :web
        resources :feature_requests, only: [ :index, :new, :create ], path: "feature-requests", controller: "feature_machine/feature_requests"
        resources :bug_reports, only: [ :index, :new, :create ], path: "bug-reports", controller: "feature_machine/bug_reports"
        get "/roadmap", to: "feature_machine/roadmap#show", as: :roadmap, format: false
      when :admin
        resource :triage, only: [ :show ], controller: "/feature_machine/admin/triage"
        resources :attachments, only: [ :create ], controller: "/feature_machine/admin/attachments"
        resources :feature_requests, only: [ :update ], controller: "/feature_machine/admin/feature_requests"
        resources :work_items, controller: "/feature_machine/admin/work_items" do
          member { post :draft }
          resources :relations, only: [ :create, :destroy ], controller: "/feature_machine/admin/work_item_relations"
        end
      when :api
        resources :feature_requests, only: [ :index, :create ], controller: "feature_machine/feature_requests"
        resources :work_items, only: [ :index, :show, :update ], controller: "feature_machine/work_items"
        resources :bug_reports, only: [ :index, :create ], controller: "feature_machine/bug_reports"
        resource :roadmap, only: [ :show ], controller: "feature_machine/roadmaps"
        namespace :maintainer do
          resources :feature_requests, only: [ :index ], controller: "/api/feature_machine/maintainer/feature_requests"
        end
      when :mcp
        post "/mcp", to: "feature_machine/mcp#handle", as: :feature_machine_mcp
        get  "/mcp", to: "feature_machine/mcp#reject_get"
      else
        raise ArgumentError, "feature_machine_routes scope must be one of #{SCOPES.inspect}, got #{scope.inspect}"
      end
    end
  end
end

ActionDispatch::Routing::Mapper.include(FeatureMachine::Routes)
