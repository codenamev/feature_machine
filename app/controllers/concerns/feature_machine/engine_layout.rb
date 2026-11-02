module FeatureMachine
  # Engine pages render through FeatureMachine.config.layout. Rails treats a
  # nil from the proc as "no opinion", so the host's inherited layout applies
  # and engine pages look like the rest of the host's.
  module EngineLayout
    extend ActiveSupport::Concern

    included do
      layout -> { FeatureMachine.config.layout }
    end
  end
end
