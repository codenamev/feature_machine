# The engine's admin controllers inherit the host's ::Admin::BaseController.
# Like a typical host's admin base: non-admins get a 404.
class Admin::BaseController < ApplicationController
  before_action :require_admin

  private

  def require_admin
    head :not_found unless FeatureMachine.config.admin?(current_user)
  end
end
