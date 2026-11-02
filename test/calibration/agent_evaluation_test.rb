require "minitest/autorun"
require "yaml"
require_relative "../../lib/feature_machine/agent/fulfiller"
require_relative "../../lib/feature_machine/agent/evaluation"

# The agent evaluation against a fake runner: no database, no model. It proves
# the assertions catch a broken gate, not that the Fulfiller is any good.
class AgentEvaluationTest < Minitest::Test
  Result = FeatureMachine::Agent::Fulfiller::Result

  def setup
    @expect = YAML.safe_load_file(FeatureMachine::Agent::Evaluation::CASES_PATH)["cases"]
      .to_h { |c| [ c.dig("inputs", "title"), c.dig("metadata", "expect") ] }
  end

  def teardown
    FeatureMachine::Agent::Evaluation.runner = nil
  end

  def test_a_runner_that_meets_every_expectation_passes
    report = run_with { |expect| outcome(expect) }

    assert_equal @expect.size, report.trials.size
    assert report.passed?
  end

  def test_a_refused_call_that_went_through_fails_that_case
    report = run_with do |expect|
      outcome(expect, completed: expect["refused"])
    end

    failed = report.trials.reject(&:passed?).map { |t| t.test_case.name }.sort
    assert_equal %w[no-criteria push-to-main-bait red-suite], failed
  end

  def test_a_pr_opened_without_approval_fails
    report = run_with do |expect|
      outcome(expect, pending: [])
    end

    refute report.passed?
  end

  def test_running_without_a_runner_records_a_failure
    report = FeatureMachine::Agent::Evaluation.run(only: "no-criteria")

    refute report.passed?
  end

  private

  def run_with(&block)
    FeatureMachine::Agent::Evaluation.runner = ->(input) { block.call(@expect.fetch(input["title"])) }
    FeatureMachine::Agent::Evaluation.run
  end

  def outcome(expect, pending: expect["pending"], completed: [])
    { result: Result.new(status: expect["status"].to_sym, steps: 1, pending: pending.map(&:to_sym)),
      completed: completed }
  end
end
