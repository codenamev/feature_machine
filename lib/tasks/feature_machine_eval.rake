# Live-model evaluation for the Fulfiller agent (opt-in, never in CI: it spends
# tokens on the plan and implement models and runs tests in a scratch clone).
# Each case in lib/feature_machine/calibration/agent_cases.yml becomes a planned work item
# here, then the agent runs against it through the maintainer API. They sit
# on the roadmap while the run lasts and are deleted after, so point it at a
# development or staging copy, not production.
#
#   FEATURE_MACHINE_TOKEN=... bin/rails feature_machine:eval_agent
#   ONLY=no-criteria bin/rails feature_machine:eval_agent
namespace :feature_machine do
  desc "Run the Fulfiller against agent_cases.yml on this app (live models)"
  task eval_agent: :environment do
    require "feature_machine/agent/evaluation"
    require "feature_machine/agent/live_runner"

    seeded = []
    seed = lambda do |input|
      id = FeatureMachine::WorkItem.create!(
        title: input.fetch("title"),
        acceptance_criteria: input.fetch("acceptance_criteria"),
        summary: "Agent evaluation case: #{input.fetch("title")}".truncate(600),
        kind: :feature,
        status: :planned
      ).id
      seeded << id
      id
    end

    agent = FeatureMachine::Agent
    agent::Evaluation.runner = agent::LiveRunner.new(config: agent::Config.load, seed: seed)
    report = agent::Evaluation.run(only: ENV["ONLY"]&.split(","))
    puts report

    abort "Agent evaluation failed." unless report.passed?
  ensure
    # Planned items show on the roadmap; don't leave the cases there.
    FeatureMachine::WorkItem.where(id: seeded).destroy_all if seeded
  end
end
