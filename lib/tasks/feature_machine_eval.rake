# Live-model evaluation for the Fulfiller agent (opt-in, never in CI: it spends
# tokens on the plan and implement models and runs tests in a scratch clone).
# Each case in test/calibration/agent_cases.yml becomes a planned work item
# here, then the agent runs against it through the maintainer API.
#
#   FEATURE_MACHINE_TOKEN=... bin/rails feature_machine:eval_agent
#   ONLY=no-criteria bin/rails feature_machine:eval_agent
namespace :feature_machine do
  desc "Run the Fulfiller against agent_cases.yml on this app (live models)"
  task eval_agent: :environment do
    require "feature_machine/agent/evaluation"
    require "feature_machine/agent/live_runner"

    seed = lambda do |input|
      FeatureMachine::WorkItem.create!(
        title: input.fetch("title"),
        acceptance_criteria: input.fetch("acceptance_criteria"),
        summary: "Agent evaluation case: #{input.fetch("title")}".truncate(600),
        kind: :feature,
        status: :planned
      ).id
    end

    agent = FeatureMachine::Agent
    agent::Evaluation.runner = agent::LiveRunner.new(config: agent::Config.load, seed: seed)
    report = agent::Evaluation.run(only: ENV["ONLY"]&.split(","))
    puts report

    abort "Agent evaluation failed." unless report.passed?
  end
end
