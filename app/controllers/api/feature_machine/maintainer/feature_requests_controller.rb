# The triage inbox as a maintainer's agent sees it: every user's requests and
# bug reports, so an agent can pull them into whatever tracker the maintainer
# triages from. Read-only on purpose. Bucketing a request into a work item,
# or declining it, stays with a human in /admin.
class Api::FeatureMachine::Maintainer::FeatureRequestsController < Api::FeatureMachine::BaseController
  before_action :authenticate_user_with_token

  # `untriaged` is the inbox: requested, not yet bucketed into a work item.
  FILTERS = (%w[untriaged] + ::FeatureMachine::Request.statuses.keys).freeze

  def index
    filter = params[:status].presence || "untriaged"
    unless FILTERS.include?(filter)
      return render_error(status: :unprocessable_entity, error: "Unknown status", code: "validation_failed",
                          resolution: "status must be one of: #{FILTERS.join(', ')}.")
    end

    scope = filter == "untriaged" ? ::FeatureMachine::Request.untriaged : ::FeatureMachine::Request.where(status: filter)
    @feature_requests = scope.includes(:user, :work_item).oldest_first
    @feature_requests = @feature_requests.where(kind: params[:kind]) if ::FeatureMachine::Request.kinds.key?(params[:kind].to_s)
  end

  private

  def required_scope
    ::FeatureMachine::MAINTAINER
  end
end
