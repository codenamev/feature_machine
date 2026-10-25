require "test_helper"

class FeatureMachine::ConfigurationTest < ActiveSupport::TestCase
  test "product_blurb falls back to product_name" do
    config = FeatureMachine::Configuration.new
    assert_equal "this app", config.product_blurb

    config.product_name = "My App"
    assert_equal "My App", config.product_blurb

    config.product_blurb = ""
    assert_equal "My App", config.product_blurb

    config.product_blurb = "My App (a todo list with an API for agents)"
    assert_equal "My App (a todo list with an API for agents)", config.product_blurb
  end

  test "layout defaults to nil so the host's own layout applies" do
    assert_nil FeatureMachine::Configuration.new.layout
    assert_nil FeatureMachine.config.layout
  end

  test "engine controllers render through the configured layout" do
    [ FeatureMachine::FeatureRequestsController, FeatureMachine::Admin::WorkItemsController,
      FeatureMachine::Admin::FeatureRequestsController, FeatureMachine::Admin::WorkItemRelationsController ].each do |controller|
      assert_includes controller.ancestors, FeatureMachine::EngineLayout, controller.name
    end
    assert File.exist?(FeatureMachine::Engine.root.join("app/views/layouts/feature_machine.html.erb"))
  end

  test "the drafter's product blurb partial renders the configured blurb" do
    original = FeatureMachine.config.product_blurb
    FeatureMachine.config.product_blurb = "Some Host (a thing agents talk to)"

    rendered = RubyLLM::Prompt.render("feature_machine/drafter/_product_blurb").strip
    assert_equal "Some Host (a thing agents talk to)", rendered
  ensure
    FeatureMachine.config.product_blurb = original
  end
end
