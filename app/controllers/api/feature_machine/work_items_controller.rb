# The hand-off surface for a maintainer's agents: read approved work items
# with their full spec, pick one up, and report progress. Drafts and declined
# items are invisible here, and nothing about triage (forming, speccing,
# approving, declining) is reachable: that stays with a human in /admin.
class Api::FeatureMachine::WorkItemsController < Api::FeatureMachine::BaseController
  before_action :authenticate_user_with_token
  before_action :set_work_item, only: %i[show update]

  rescue_from ::FeatureMachine::WorkItem::InvalidTransition, with: :render_invalid_transition

  STATUSES = %w[planned in_progress in_review shipped].freeze

  # Defaults to the pickup queue: planned work, oldest first.
  def index
    status = params[:status].presence || "planned"
    unless STATUSES.include?(status)
      return render_error(status: :unprocessable_entity, error: "Unknown status", code: "validation_failed",
                          resolution: "status must be one of: #{STATUSES.join(', ')}.")
    end

    @work_items = ::FeatureMachine::WorkItem.where(status: status).includes(feature_requests: :user).order(:created_at)
  end

  def show
  end

  # Only `status`, `progress_note` and `pull_request_url`. The spec is the
  # human's; an agent that disagrees with it says so in the progress note.
  # Sending the status an item already has is a conflict, not a no-op: that is
  # what stops a second agent picking up work someone already has. To add a
  # note or a pull request, send only that.
  def update
    attributes = params.require(:work_item).permit(:status, :progress_note, :pull_request_url)
    changes = attributes.slice(:progress_note, :pull_request_url)
    attributes[:status].present? ? @work_item.agent_transition!(attributes[:status], changes) : @work_item.update!(changes)
    render :show
  rescue ActiveRecord::RecordInvalid => e
    render_error(status: :unprocessable_entity, error: "Validation failed", code: "validation_failed", errors: e.record.errors.full_messages,
                 resolution: "Asking for review needs `pull_request_url`: a GitHub pull request URL.")
  end

  private

  def required_scope
    ::FeatureMachine::MAINTAINER
  end

  def set_work_item
    @work_item = ::FeatureMachine::WorkItem.where(status: STATUSES).find(params[:id])
  end

  def render_invalid_transition(exception)
    render_error(status: :conflict, error: exception.message, code: "invalid_transition",
                 resolution: "Re-read the work item: another agent may have picked it up, or it may already be shipped.")
  end
end
