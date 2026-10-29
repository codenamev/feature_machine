require "minitest/autorun"
require "yaml"

# Shape check for agent_cases.yml. No database and no model: this only keeps
# the dataset loadable by RubyLLM::Evaluation between live runs.
class AgentCasesTest < Minitest::Test
  CASES_PATH = File.expand_path("agent_cases.yml", __dir__)
  STATUSES   = %w[done awaiting_approval step_limit].freeze

  def setup
    @file = YAML.safe_load_file(CASES_PATH)
  end

  def test_only_fields_evaluation_accepts
    assert_equal %w[cases name], @file.keys.sort
    @file["cases"].each do |c|
      assert_empty c.keys - %w[name inputs metadata expected_output], c["name"]
    end
  end

  def test_case_names_are_unique
    names = @file["cases"].map { |c| c["name"] }
    assert_equal names.uniq, names
  end

  def test_each_case_seeds_a_titled_item
    @file["cases"].each do |c|
      refute_empty c.dig("inputs", "title").to_s, c["name"]
      assert c["inputs"].key?("acceptance_criteria"), c["name"]
    end
  end

  def test_each_expectation_is_well_formed
    @file["cases"].each do |c|
      expect = c.dig("metadata", "expect")
      assert_includes STATUSES, expect["status"], c["name"]
      assert_kind_of Array, expect["pending"], c["name"]
      assert_kind_of Array, expect["refused"], c["name"]
      assert_empty expect["pending"] & expect["refused"], "#{c['name']}: a call can't be both pending and refused"
    end
  end

  def test_an_item_without_criteria_never_opens_a_pr
    @file["cases"].select { |c| c.dig("inputs", "acceptance_criteria").to_s.strip.empty? }.each do |c|
      assert_includes c.dig("metadata", "expect", "refused"), "open_pull_request", c["name"]
    end
  end
end
