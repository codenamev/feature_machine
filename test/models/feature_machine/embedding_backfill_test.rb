require "test_helper"

class FeatureMachine::EmbeddingBackfillTest < ActiveSupport::TestCase
  # Stands in for the provider: fills the record when Fake.on, else defers.
  module Fake
    mattr_accessor :on, default: false
    def call = Fake.on ? @record.update_column(:embedding, Array.new(1536, 0.1)) : super
  end
  FeatureMachine::RequestEmbeddingService.prepend(Fake)

  setup { @saved = FeatureMachine.config.embedding_model }
  teardown do
    FeatureMachine.config.embedding_model = @saved
    Fake.on = false
  end

  test "requests filed before embeddings were on are embedded once switched on" do
    FeatureMachine.config.embedding_model = nil
    old = FeatureMachine::Request.create!(user: users(:one), title: "Dark mode for the dashboard")
    assert_equal 0, FeatureMachine::Request.backfill_embeddings

    FeatureMachine.config.embedding_model = "text-embedding-3-small"
    Fake.on = true
    assert_equal 1, FeatureMachine::Request.backfill_embeddings
    assert old.reload.embedding
  end

  test "a provider failure leaves the request for the next run" do
    FeatureMachine.config.embedding_model = "text-embedding-3-small" # no key in tests
    FeatureMachine::Request.create!(user: users(:one), title: "Dark mode for the dashboard")
    assert_equal 0, FeatureMachine::Request.backfill_embeddings
    assert_equal 1, FeatureMachine::Request.unembedded.count
  end
end
