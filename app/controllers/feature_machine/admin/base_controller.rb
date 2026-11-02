# Every engine admin page. Anyone config.admin doesn't vouch for gets a 404
# rather than a 403, so the admin surface doesn't advertise itself. The
# parent is the host's (config.admin_parent_controller), so its layout and
# any admin filters of its own still apply.
class FeatureMachine::Admin::BaseController < FeatureMachine.config.admin_parent_controller.constantize
  include FeatureMachine::CurrentUser
  include FeatureMachine::EngineLayout

  before_action :require_feature_machine_admin

  private

  def require_feature_machine_admin
    head :not_found unless FeatureMachine.config.admin?(feature_machine_user)
  end
end
