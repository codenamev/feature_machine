# Agents report bugs for the user who handed them a token, and follow that
# user's own reports.
class Api::FeatureMachine::BugReportsController < Api::FeatureMachine::BaseController
  before_action :authenticate_user_with_token

  def index
    @feature_requests = ::FeatureMachine::Request.owned_by(api_user).bug.includes(:user, :work_item).newest_first
    render "api/feature_machine/feature_requests/index"
  end

  def create
    @feature_request = ::FeatureMachine::Request.owned_by(api_user).bug.build(bug_report_params)

    if @feature_request.save
      render "api/feature_machine/feature_requests/show", status: :created
    else
      render_error(
        status: :unprocessable_entity,
        error: "Validation failed",
        code: "validation_failed",
        errors: @feature_request.errors.full_messages,
        resolution: "Title is required (8-120 characters). Description is optional, up to 2000 characters."
      )
    end
  end

  private

  def bug_report_params
    params.require(:bug_report).permit(:title, :description)
  end
end
