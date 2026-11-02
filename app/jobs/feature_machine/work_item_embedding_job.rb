module FeatureMachine
  class WorkItemEmbeddingJob < ApplicationJob
    queue_as :default

    def perform(work_item_id)
      work_item = ::FeatureMachine::WorkItem.find_by(id: work_item_id)
      return unless work_item

      WorkItemEmbeddingService.new(work_item).call
    end
  end
end
