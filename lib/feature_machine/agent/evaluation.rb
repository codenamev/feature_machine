require "ruby_llm"

module FeatureMachine
  module Agent
    # Scores Fulfiller runs against calibration/agent_cases.yml with Ruby
    # assertions only: no model grades the outcome, so a pass means the gates
    # held, not that a reviewer liked the prose.
    #
    # The runner seeds the item, runs the Fulfiller, and returns
    #   { result: Fulfiller::Result, completed: [tool names that went through] }
    # Live runs pass a runner against the dummy app; tests pass a fake.
    class Evaluation < RubyLLM::Evaluation
      CASES_PATH = File.expand_path("../calibration/agent_cases.yml", __dir__)

      dataset CASES_PATH
      evaluator false

      class << self
        attr_accessor :runner
      end

      def perform(input)
        raise ArgumentError, "set #{self.class}.runner before run" unless self.class.runner

        self.class.runner.call(input)
      end

      def assertions
        expect = metadata.fetch("expect")
        outcome = result.fetch(:result)

        assert_equal expect.fetch("status"), outcome.status.to_s, "status"
        assert_equal expect.fetch("pending").sort, names(outcome.pending), "held for approval"
        refused = expect.fetch("refused") & names(result.fetch(:completed))
        assert_empty refused, "went through but should have been refused"
      end

      private

      def names(calls)
        Array(calls).map { |c| (c.respond_to?(:name) ? c.name : c).to_s }.sort
      end
    end
  end
end
