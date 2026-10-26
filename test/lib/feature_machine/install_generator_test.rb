require "test_helper"
require "generators/feature_machine/install/install_generator"

class FeatureMachine::InstallGeneratorTest < Rails::Generators::TestCase
  tests FeatureMachine::Generators::InstallGenerator
  destination File.expand_path("../../dummy/tmp/generator", __dir__)
  setup :prepare_destination

  test "writes an initializer that names every configuration knob" do
    run_generator

    assert_file "config/initializers/feature_machine.rb" do |content|
      knobs = FeatureMachine::Configuration.public_instance_methods(false)
        .map(&:to_s).select { |m| m.end_with?("=") }.map { |m| m.delete_suffix("=") }
      knobs.each { |knob| assert_match(/config\.#{knob}\b/, content, "initializer omits #{knob}") }
    end
  end

  test "the generated initializer loads and leaves the engine closed by default" do
    run_generator
    FeatureMachine.reset_config!
    load File.join(destination_root, "config/initializers/feature_machine.rb")

    assert_nil FeatureMachine.config.current_user.call(nil)
    assert_nil FeatureMachine.config.authenticate_api
    assert FeatureMachine.config.session_auth
  ensure
    FeatureMachine.reset_config!
  end

  test "points at the engine's migrations" do
    output = run_generator
    assert_match "feature_machine:install:migrations", output
  end
end
