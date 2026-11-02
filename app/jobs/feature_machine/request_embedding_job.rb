module FeatureMachine
  class RequestEmbeddingJob < ApplicationJob
    queue_as :default

    def perform(feature_request_id)
      feature_request = ::FeatureMachine::Request.find_by(id: feature_request_id)
      return unless feature_request

      RequestEmbeddingService.new(feature_request).call
    end
  end
end
