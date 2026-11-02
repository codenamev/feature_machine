module FeatureMachine
  # The engine's own job base, so a host needs no ApplicationJob of its own.
  # Queue adapter and the like still come from the host's Active Job config.
  class ApplicationJob < ActiveJob::Base
  end
end
