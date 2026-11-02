# The engine's signed-in pages: your requests, your bug reports, the roadmap.
# The parent is the host's (config.parent_controller, ApplicationController by
# default), so its layout and auth filters run first; the engine then insists
# on a user of its own from config.current_user.
class FeatureMachine::BaseController < FeatureMachine.config.parent_controller.constantize
  include FeatureMachine::CurrentUser
  include FeatureMachine::EngineLayout

  before_action :require_feature_machine_user
end
