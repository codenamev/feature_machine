require "test_helper"

class FeatureMachine::RoutesTest < ActiveSupport::TestCase
  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      feature_machine_routes :web
      namespace :admin do
        feature_machine_routes :admin
      end
      namespace :api, defaults: { format: :json } do
        feature_machine_routes :api
      end
    end
  end

  test "web scope keeps the hyphenated feature-requests path" do
    assert_recognizes_with({ controller: "feature_machine/feature_requests", action: "index" }, "/feature-requests")
    assert_recognizes_with({ controller: "feature_machine/feature_requests", action: "create" }, "/feature-requests", :post)
  end

  test "admin scope routes to the engine's admin controllers, not admin/feature_machine" do
    assert_recognizes_with({ controller: "feature_machine/admin/work_items", action: "draft", id: "7" }, "/admin/work_items/7/draft", :post)
    assert_recognizes_with({ controller: "feature_machine/admin/work_item_relations", action: "create", work_item_id: "7" }, "/admin/work_items/7/relations", :post)
    assert_recognizes_with({ controller: "feature_machine/admin/feature_requests", action: "update", id: "3" }, "/admin/feature_requests/3", :patch)
  end

  test "api scope keeps json defaults and the api helper names" do
    # Not recognize_path: the api controllers inherit the host's Api::BaseController.
    route = @routes.named_routes[:api_work_item]
    assert_equal({ controller: "api/feature_machine/work_items", action: "show", format: :json }, route.defaults)
    helpers = @routes.url_helpers
    assert_equal "/api/work_items/5", helpers.api_work_item_path(5)
    assert_equal "/admin/work_items", helpers.admin_work_items_path
    assert_equal "/feature-requests/new", helpers.new_feature_request_path
  end

  test "rejects an unknown scope" do
    error = assert_raises(ArgumentError) { ActionDispatch::Routing::RouteSet.new.draw { feature_machine_routes :public } }
    assert_match "must be one of", error.message
  end

  private
    def assert_recognizes_with(expected, path, method = :get)
      assert_equal expected.transform_values(&:to_s).transform_keys(&:to_sym),
        @routes.recognize_path(path, method: method).transform_values(&:to_s)
    end
end
