require "test_helper"

class FeatureMachine::JudgeTest < ActiveSupport::TestCase
  setup { @before = FeatureMachine.config.dup }
  teardown { FeatureMachine.instance_variable_set(:@config, @before) }

  def settings = FeatureMachine::Judge.model.transform_values { _1.respond_to?(:call) ? _1.call : _1 }

  test "a registry model needs no provider" do
    FeatureMachine.config.judgment_model = "jev-latest"
    assert_equal({ model: "jev-latest", provider: nil, assume_model_exists: false }, settings)
  end

  test "a named provider reaches a local server's own model id" do
    FeatureMachine.config.judgment_model = "local-jev"
    FeatureMachine.config.judgment_provider = :typesafe
    assert_equal({ model: "local-jev", provider: :typesafe, assume_model_exists: true }, settings)
  end
end
