# What the install generator draws, verbatim.
Rails.application.routes.draw do
  feature_machine_routes :web
  namespace :admin do
    feature_machine_routes :admin
  end
  namespace :api, defaults: { format: :json } do
    feature_machine_routes :api
  end
  feature_machine_routes :mcp
end
