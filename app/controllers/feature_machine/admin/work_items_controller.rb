class FeatureMachine::Admin::WorkItemsController < FeatureMachine::Admin::BaseController
  before_action :set_work_item, only: %i[show edit update destroy draft]

  def index
    grouped = ::FeatureMachine::WorkItem.includes(:feature_requests).newest_first.group_by(&:status)
    @work_items = ::FeatureMachine::WorkItem::ADMIN_ORDER.index_with { |status| grouped.fetch(status, []) }
  end

  # The hand-off view. `.md` is the same spec as a document to paste into an
  # issue tracker or hand to whoever builds it.
  def show
    respond_to do |format|
      format.html
      format.md { render layout: false }
    end
  end

  def new
    @work_item = ::FeatureMachine::WorkItem.new(kind: params[:kind].presence_in(::FeatureMachine::WorkItem.kinds.keys) || "feature")
  end

  # Two ways in: the blank form, or "form a work item" on a triage bucket,
  # which arrives with request_ids and drafts the whole spec from them.
  def create
    requests = ::FeatureMachine::Request.untriaged.where(id: params[:request_ids]).includes(:user).oldest_first
    return create_from_requests(requests) if requests.any?

    @work_item = ::FeatureMachine::WorkItem.new(work_item_params)
    if @work_item.save
      redirect_to edit_admin_work_item_path(@work_item), notice: "Work item created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  # Also serves the one-click review decisions on the show page (ship it,
  # send it back), which post just a status.
  def update
    if @work_item.update(work_item_params)
      redirect_to admin_work_item_path(@work_item), notice: @work_item.saved_change_to_status? ? "Now #{helpers.work_item_status_label(@work_item.status).downcase}." : "Work item saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @work_item.destroy!
    redirect_to admin_work_items_path, notice: "Work item deleted. Its requests are back in triage."
  end

  # Rewrites the spec from the item's requests. Always lands on the edit
  # form: a draft is something to review, never something to publish as-is.
  def draft
    draft = ::FeatureMachine::WorkItemDrafter.new(@work_item.feature_requests.includes(:user).oldest_first, kind: @work_item.kind).call

    if @work_item.update(draft.attributes)
      redirect_to edit_admin_work_item_path(@work_item),
        notice: draft.from_model? ? "Spec drafted from the requests. Review it before planning." : "The model was unavailable, so the spec is a plain digest of the requests."
    else
      redirect_to edit_admin_work_item_path(@work_item), alert: "Draft could not be saved: #{@work_item.errors.full_messages.to_sentence}"
    end
  end

  private

  # The draft is written by the model from user text, so it always opens in
  # the editor as a private draft; planning it is a separate, human step.
  def create_from_requests(requests)
    draft = ::FeatureMachine::WorkItemDrafter.new(requests).call
    work_item = ::FeatureMachine::WorkItem.create!(draft.attributes.merge(kind: requests.first.kind))
    requests.each { |request| request.update!(work_item: work_item) }

    formed = "Work item formed from #{helpers.pluralize(requests.size, 'request')}."
    redirect_to edit_admin_work_item_path(work_item),
      notice: draft.from_model? ? "#{formed} The spec is a first draft: review it before planning." : "#{formed} The model was unavailable, so only the problem is filled in, from the requests."
  end

  def set_work_item
    @work_item = ::FeatureMachine::WorkItem.find(params[:id])
  end

  def work_item_params
    params.expect(work_item: [ :title, :kind, :status, :summary, :problem, :scope, :acceptance_criteria, :progress_note, :pull_request_url ])
  end
end
