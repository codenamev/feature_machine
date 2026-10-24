class FeatureMachine::FeatureRequestsController < ApplicationController
  include FeatureMachine::EngineLayout

  # "Your feature requests": only ever the signed-in user's own. What everyone
  # can see is the roadmap, which lists work items rather than requests.
  def index
    @feature_requests = current_user.feature_requests.feature.includes(:work_item).newest_first
  end

  def new
    @feature_request = ::FeatureMachine::Request.new
  end

  def create
    @feature_request = current_user.feature_requests.build(feature_request_params)

    if @feature_request.save
      redirect_to feature_requests_path, notice: "Thanks. Its status will update here."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def feature_request_params
    params.expect(feature_request: [ :title, :description ])
  end
end
