# The triage inbox: untriaged requests, bucketed by similarity and ranked by
# how many different people asked.
class FeatureMachine::Admin::TriageController < FeatureMachine::Admin::BaseController
  def show
    @buckets = ::FeatureMachine::TriageBuckets.new.call
    @request_count = @buckets.sum { |bucket| bucket.requests.size }
    @work_items = ::FeatureMachine::WorkItem.active.order(:title)
  end
end
