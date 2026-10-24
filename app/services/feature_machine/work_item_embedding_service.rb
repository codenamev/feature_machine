module FeatureMachine
  class WorkItemEmbeddingService < BaseEmbeddingService
    private

    # The host picks the model (nowreading#102, phase 3c-i); nil = embeddings off.
    def embedding_model
      ::FeatureMachine.config.embedding_model
    end

    def input_text
      @input_text ||= [ @record.title, @record.summary, @record.problem, @record.scope ].compact_blank.join("\n\n")
    end
  end
end
