namespace :feature_machine do
  desc "Embed requests filed before config.embedding_model was set"
  task embed_requests: :environment do
    abort "feature_machine.embedding_model is nil; nothing to embed." unless FeatureMachine.config.embeddings?

    filled = FeatureMachine::Request.backfill_embeddings
    missing = FeatureMachine::Request.unembedded.count
    puts "Embedded #{filled}; #{missing} still missing#{' (see the log for why)' if missing.positive?}."
  end
end
