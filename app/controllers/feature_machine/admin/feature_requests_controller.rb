# Per-request triage decisions: move a request into or out of a work item,
# decline it with a note, or reopen it.
class FeatureMachine::Admin::FeatureRequestsController < FeatureMachine::Admin::BaseController
  def update
    feature_request = ::FeatureMachine::Request.find(params[:id])
    attributes = params.expect(feature_request: [ :work_item_id, :status, :progress_note ])
    # Which statuses an admin may set lives on the model.
    return head :unprocessable_entity unless feature_request.update(attributes)

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
