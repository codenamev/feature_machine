# Live-model calibration for FeatureMachine::Judge (opt-in, never in CI: it
# spends tokens on config.judgment_model). Fails if an equivalent mutant moves
# an answer past threshold, or a faulty mutant doesn't move it.
namespace :feature_machine do
  desc "Run the Judge mutation calibration cases against config.judgment_model"
  task calibrate_judge: :environment do
    abort "feature_machine.judgment_model is nil; nothing to calibrate." unless FeatureMachine.config.judge?

    require "feature_machine/judge_calibration"
    checks = FeatureMachine::JudgeCalibration.load.run
    checks.each { |c| puts "#{c.ok ? "ok  " : "FAIL"} #{c.case_id} #{c.variant}: #{c.detail}" }

    failed = checks.reject(&:ok)
    puts "\n#{checks.size - failed.size}/#{checks.size} checks held on #{FeatureMachine.config.judgment_model}."
    abort "#{failed.size} calibration checks failed." if failed.any?
  end
end
