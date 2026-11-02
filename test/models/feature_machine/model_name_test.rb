require "test_helper"

# Phase 2 moved these models under FeatureMachine:: and overrode model_name so
# params, dom_id, route helpers and i18n keys stay exactly as they were. These
# pin that promise: a failure here means the namespace leaked into the wire
# format (strong params, redirect anchors, polymorphic url_for, locale keys).
class FeatureMachineModelNameTest < ActiveSupport::TestCase
  {
    FeatureMachine::Request          => %w[FeatureRequest feature_request feature_requests],
    FeatureMachine::WorkItem         => %w[WorkItem work_item work_items],
    FeatureMachine::WorkItemRelation => %w[WorkItemRelation work_item_relation work_item_relations]
  }.each do |klass, (name, singular, plural)|
    test "#{klass} keeps the pre-namespace model_name" do
      model_name = klass.model_name

      assert_equal name, model_name.name
      assert_equal singular, model_name.param_key
      assert_equal singular, model_name.singular_route_key
      assert_equal plural, model_name.route_key
      assert_equal singular, model_name.i18n_key.to_s
    end
  end

  test "legacy top-level aliases are gone" do
    %w[FeatureRequest WorkItem WorkItemRelation TriageBuckets WorkItemDrafter].each do |name|
      assert_not Object.const_defined?(name), "#{name} alias should not exist"
    end
  end
end
