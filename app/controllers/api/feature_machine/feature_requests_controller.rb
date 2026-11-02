# Agents file feature requests for the user who handed them a token, and
# follow that user's own requests. No one reads anyone else's.
class Api::FeatureMachine::FeatureRequestsController < Api::FeatureMachine::BaseController
  before_action :authenticate_user_with_token

  def index
    @feature_requests = ::FeatureMachine::Request.owned_by(api_user).feature.includes(:user, :work_item).newest_first
  end

  def create
    @feature_request = ::FeatureMachine::Request.owned_by(api_user).feature.build(feature_request_params)

    if @feature_request.save
      render :show, status: :created
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

  def feature_request_params
    params.require(:feature_request).permit(:title, :description)
  end
end
