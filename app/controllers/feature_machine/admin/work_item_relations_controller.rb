class FeatureMachine::Admin::WorkItemRelationsController < FeatureMachine::Admin::BaseController
  before_action :set_work_item

  def create
    relation = @work_item.outgoing_relations.build(params.expect(work_item_relation: [ :to_work_item_id, :kind ]))

    if relation.save
      redirect_to admin_work_item_path(@work_item), notice: "Linked."
    else
      redirect_to admin_work_item_path(@work_item), alert: relation.errors.full_messages.to_sentence
    end
  end

  def destroy
    @work_item.relations.find(params[:id]).destroy!
    redirect_to admin_work_item_path(@work_item), notice: "Link removed."
  end

  private

  def set_work_item
    @work_item = ::FeatureMachine::WorkItem.find(params[:work_item_id])
  end
end
