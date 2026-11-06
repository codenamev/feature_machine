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

  test "draws the engine's routes into config/routes.rb" do
    write_routes
    run_generator

    assert_file "config/routes.rb" do |content|
      assert_match(/^  feature_machine_routes :web$/, content)
      assert_match(/namespace :admin do\n\s+feature_machine_routes :admin\n/, content)
      assert_match(/namespace :api, defaults: \{ format: :json \} do\n\s+feature_machine_routes :api\n/, content)
      assert_match(/^  feature_machine_routes :mcp$/, content)
    end
  end

  test "leaves routes alone when the host already calls the macro" do
    write_routes("  feature_machine_routes :web\n")
    run_generator

    assert_file "config/routes.rb" do |content|
      assert_equal 1, content.scan("feature_machine_routes").size
    end
  end

  test "skips routes without failing when config/routes.rb is missing" do
    output = run_generator
    assert_match "add the feature_machine_routes calls yourself", output
    assert_no_file "config/routes.rb"
  end

  test "reads the session cookie when the app has Rails' authentication generator" do
    write_session_model
    run_generator
    FeatureMachine.reset_config!
    load File.join(destination_root, "config/initializers/feature_machine.rb")

    session = Struct.new(:user).new(:alice)
    jar = Struct.new(:signed).new({ session_id: 7 })
    request = Struct.new(:cookie_jar).new(jar)
    finder = Module.new { define_singleton_method(:find_by) { |id:| id == 7 ? session : nil } }
    Object.const_set(:Session, finder)

    assert_equal :alice, FeatureMachine.config.current_user.call(request)
  ensure
    Object.send(:remove_const, :Session) if Object.const_defined?(:Session, false) && Session == finder
    FeatureMachine.reset_config!
  end

  test "warns when Rails' authentication has no root route to land on" do
    write_session_model
    write_routes
    output = run_generator
    assert_match "has no root route", output
  end

  test "stays quiet about the root route when one exists" do
    write_session_model
    write_routes("  root \"home#index\"\n")
    output = run_generator
    assert_no_match "has no root route", output
  end

  test "stays quiet about the root route without Rails' authentication" do
    write_routes
    output = run_generator
    assert_no_match "has no root route", output
  end

  private
    def write_session_model
      FileUtils.mkdir_p File.join(destination_root, "app/models")
      File.write File.join(destination_root, "app/models/session.rb"), "class Session < ApplicationRecord\nend\n"
    end

    def write_routes(body = "")
      FileUtils.mkdir_p File.join(destination_root, "config")
      File.write File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\n#{body}end\n"
    end
end
