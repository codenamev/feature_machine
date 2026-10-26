require "minitest/autorun"
require "yaml"

# Shape check for judge_cases.yml. No database and no model: the live run is
# `rake feature_machine:calibrate_judge`, and this only keeps the file honest.
class JudgeCasesTest < Minitest::Test
  CASES_PATH = File.expand_path("judge_cases.yml", __dir__)
  QUESTIONS  = {
    "bug"                    => %w[high low],
    "duplicate_of_open_item" => %w[high low],
    "clarity"                => %w[Low Mid High]
  }.freeze

  def setup
    @file = YAML.safe_load_file(CASES_PATH)
  end

  def test_every_question_has_a_case
    assert_equal QUESTIONS.keys.sort, @file["cases"].map { |c| c["question"] }.uniq.sort
  end

  def test_case_ids_are_unique
    ids = @file["cases"].map { |c| c["id"] }
    assert_equal ids.uniq, ids
  end

  def test_each_case_has_base_and_both_mutants
    @file["cases"].each do |c|
      %w[base equivalent faulty].each do |variant|
        request = c.fetch(variant)
        assert request.key?("title"), "#{c["id"]} #{variant} needs a title"
        assert request.key?("description"), "#{c["id"]} #{variant} needs a description"
      end
      refute c["equivalent"].key?("expect"), "#{c["id"]}: an equivalent mutant inherits the base answer"
    end
  end

  def test_expectations_are_valid_and_faulty_moves
    @file["cases"].each do |c|
      allowed = QUESTIONS.fetch(c["question"])
      assert_includes allowed, c["base"]["expect"], c["id"]
      assert_includes allowed, c["faulty"]["expect"], c["id"]
      refute_equal c["base"]["expect"], c["faulty"]["expect"], "#{c["id"]}: a faulty mutant must change the answer"
    end
  end

  def test_thresholds_and_context_present
    assert_kind_of Numeric, @file.dig("thresholds", "probability_drift")
    assert_kind_of Integer, @file.dig("thresholds", "score_drift")
    refute_empty @file["open_items"]
  end
end
