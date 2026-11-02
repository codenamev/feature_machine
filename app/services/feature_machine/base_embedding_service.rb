require "digest"

module FeatureMachine
  # Embeds one record's text into its `embedding` column, skipping the call
  # when the text hasn't changed since the last embedding. Subclasses say
  # which text (#input_text) and which model (#embedding_model; nil turns
  # embedding off). A failed provider call logs and leaves the record as it
  # was: the request is still filed, it just waits unbucketed in triage.
  class BaseEmbeddingService
    def initialize(record)
      @record = record
    end

    # @return [Boolean] whether a new embedding was written
    def call
      return false if embedding_model.nil?
      return false if input_text.blank?
      return false if up_to_date?

      vector = fetch_embedding
      return false unless vector

      @record.update_columns(embedding: vector, embedded_at: Time.current, embedding_input_digest: input_digest)
      true
    end

    private

    def up_to_date?
      @record.embedding.present? && @record.embedding_input_digest == input_digest
    end

    def input_digest
      @input_digest ||= Digest::SHA256.hexdigest(input_text)
    end

    def input_text
      raise NotImplementedError, "#{self.class} must define #input_text"
    end

    def embedding_model
      raise NotImplementedError, "#{self.class} must define #embedding_model"
    end

    def fetch_embedding
      RubyLLM.embed(input_text, model: embedding_model).vectors
    rescue => e
      Rails.logger.error "#{@record.class.name} embedding failed for #{@record.id}: #{e.message}"
      nil
    end
  end
end
