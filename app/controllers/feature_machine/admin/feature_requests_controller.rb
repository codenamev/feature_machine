# Per-request triage decisions: move a request into or out of a work item,
# decline it with a note, or reopen it.
class FeatureMachine::Admin::FeatureRequestsController < ::Admin::BaseController
  include FeatureMachine::EngineLayout

  # The only statuses an admin sets on a request directly; every other status
  # comes from its work item.
  DIRECT_STATUSES = %w[requested declined].freeze

  def update
    feature_request = ::FeatureMachine::Request.find(params[:id])
    attributes = params.expect(feature_request: [ :work_item_id, :status, :progress_note ])
    return head :unprocessable_entity if attributes[:status].present? && DIRECT_STATUSES.exclude?(attributes[:status])

    feature_request.update!(attributes)
    redirect_back fallback_location: admin_triage_path, notice: notice_for(feature_request)
  end

  private

  def notice_for(feature_request)
    if feature_request.work_item
      "Attached to \"#{feature_request.work_item.title}\"."
    elsif feature_request.declined?
      "Request declined."
    else
      "Request is back in triage."
    end
  end
end
