# Attaches untriaged requests (typically a whole triage bucket) to an
# existing work item.
class FeatureMachine::Admin::AttachmentsController < FeatureMachine::Admin::BaseController
  def create
    return redirect_to(admin_triage_path, alert: "Choose a work item to add those requests to.") if params[:work_item_id].blank?

    # Only items still in play: attaching to a shipped or declined one would
    # stamp the requests with that outcome straight away.
    work_item = ::FeatureMachine::WorkItem.active.find(params[:work_item_id])
    requests = ::FeatureMachine::Request.untriaged.where(id: params[:request_ids]).to_a
    ::FeatureMachine::Request.transaction do
      requests.each { |request| request.update!(work_item: work_item) }
    end

    redirect_to admin_triage_path, notice: "#{helpers.pluralize(requests.size, 'request')} attached to \"#{work_item.title}\"."
  end
end
