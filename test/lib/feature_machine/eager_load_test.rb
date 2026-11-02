require "test_helper"

# Every class the engine ships has to load in a host that brings nothing of
# its own. The dummy doesn't eager-load, so without this a class that names a
# missing constant or misuses a gem's DSL at load time only fails in
# production, the first time its feature is switched on.
class FeatureMachine::EagerLoadTest < ActiveSupport::TestCase
  test "every engine constant loads" do
    root = FeatureMachine::Engine.root.join("app")
    %w[controllers models services jobs tools helpers].each do |dir|
      Rails.autoloaders.main.eager_load_dir(root.join(dir).to_s)
    rescue NameError, ArgumentError => e
      flunk "app/#{dir} failed to load: #{e.class}: #{e.message}"
    end
    assert defined?(FeatureMachine::McpController), "the MCP controller is among them"
  end

  # RubyLLM checks a question's criteria when it judges, not when the class
  # is declared, so a malformed one only surfaces on the first live triage.
  test "the judge's three questions are well formed" do
    questions = FeatureMachine::Judge.question_definitions
    assert_equal %w[bug duplicate_of_open_item clarity], questions.keys
    questions.each_value(&:validate!)
  end
end
