require "minitest/autorun"
require "ruby_llm"
require_relative "../../app/services/feature_machine/judge"
require_relative "../../lib/feature_machine/judge_calibration"

# The calibration runner against a fake judge: no database, no model. The live
# run is `rake feature_machine:calibrate_judge`.
class JudgeCalibrationTest < Minitest::Test
  Answer = Struct.new(:probability, :score, keyword_init: true)

  def setup
    @calibration_file = YAML.safe_load_file(FeatureMachine::JudgeCalibration::CASES_PATH)
    @by_text = @calibration_file["cases"].each_with_object({}) do |c, index|
      %w[base equivalent faulty].each do |variant|
        expect = variant == "faulty" ? c["faulty"]["expect"] : c["base"]["expect"]
        index["Title: #{c[variant]["title"]}\n\n#{c[variant]["description"]}"] = [ c["question"], expect ]
      end
    end
  end

  def test_a_judge_that_answers_every_case_right_passes
    checks = run_with { |question, expect| answer(question, expect) }

    assert_equal @calibration_file["cases"].size * 3, checks.size
    assert checks.all?(&:ok), checks.reject(&:ok).map(&:detail).join("\n")
  end

  def test_a_judge_that_ignores_the_request_fails_every_faulty_mutant
    checks = run_with { |question, _expect| answer(question, question == "clarity" ? "Mid" : "low") }

    assert checks.select { |c| c.variant == "faulty" }.any? { |c| !c.ok }
    assert checks.select { |c| c.variant == "equivalent" }.all?(&:ok), "a constant judge never drifts"
  end

  def test_paraphrase_drift_past_threshold_fails_the_equivalent_check
    probe = "bug-stuck-drafts"
    equivalent = @calibration_file["cases"].find { |c| c["id"] == probe }["equivalent"]
    checks = run_with do |question, expect, text|
      text.include?(equivalent["title"]) ? Answer.new(probability: 0.55) : answer(question, expect)
    end

    failed = checks.reject(&:ok).map { |c| [ c.case_id, c.variant ] }
    assert_equal [ [ probe, "equivalent" ] ], failed
  end

  private

  def run_with(&block)
    judge = lambda do |text, context|
      assert_includes context, "- [feature] Pin articles to the top of a public list"
      question, expect = @by_text.find { |key, _| text.end_with?(key) }.last
      { question.to_sym => block.call(question, expect, text) }
    end
    FeatureMachine::JudgeCalibration.new(@calibration_file, judge: judge).run
  end

  def answer(question, expect)
    return Answer.new(score: %w[Low Mid High].index(expect)) if question == "clarity"

    Answer.new(probability: expect == "high" ? 0.9 : 0.1)
  end
end
