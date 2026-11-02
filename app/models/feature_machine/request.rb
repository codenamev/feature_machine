# Something a user asked the host app for: a feature, or a bug report. This
# is the raw intake record, in the requester's own words. What actually gets
# built is a WorkItem; triage is the act of bucketing requests into one.
#
# A request is visible to the person who filed it and to admins, never to
# other users. What everyone signed in can see is the roadmap of work items.
#
# Requesters can only create. A request's status follows its work item; the
# only status an admin sets directly is `declined`.
module FeatureMachine
  class Request < ApplicationRecord
    self.table_name = "feature_requests"

    # Phase 2 keeps the public surface unchanged: params keys, dom_id,
    # polymorphic route helpers and i18n keys all still read `feature_request`.
    def self.model_name
      @_model_name ||= ActiveModel::Name.new(self, nil, "FeatureRequest")
    end

    belongs_to :user, class_name: ::FeatureMachine.config.user_class
    belongs_to :work_item, class_name: "FeatureMachine::WorkItem", optional: true

    enum :kind, { feature: 0, bug: 1 }, validate: true
    enum :status, { requested: 0, planned: 1, in_progress: 2, shipped: 3, declined: 4 }, validate: true

    has_neighbors :embedding

    validates :title, presence: true, length: { minimum: 8, maximum: 120 }
    validates :description, length: { maximum: 2000 }
    validates :progress_note, length: { maximum: 1000 }

    scope :newest_first, -> { order(created_at: :desc) }
    scope :oldest_first, -> { order(created_at: :asc) }
    scope :embedded,     -> { where.not(embedding: nil) }
    # Still waiting for an admin: not bucketed into a work item, not declined.
    scope :untriaged,    -> { requested.where(work_item_id: nil) }

    before_save :follow_work_item, if: :will_save_change_to_work_item_id?
    before_save :stamp_shipped_at
    after_commit :enqueue_embedding, on: [ :create, :update ], if: :embedding_wanted?
    # Hosts hear about status moves (planned, shipped, declined...) to tell the
    # requester wherever they asked; the engine itself only shows the roadmap.
    after_update_commit :announce_status_change, if: -> { saved_change_to_status? && ::FeatureMachine.config.on_status_change }

    private

    # Joining a work item means taking on its public state; leaving one puts
    # the request back in the triage inbox.
    def follow_work_item
      if work_item
        assign_attributes(work_item.request_attributes)
      else
        assign_attributes(status: :requested, progress_note: nil, shipped_at: nil)
      end
    end

    def stamp_shipped_at
      self.shipped_at ||= Time.current if shipped? && (new_record? || will_save_change_to_status?)
    end

    def embedding_wanted?
      ::FeatureMachine.config.embeddings? && embedding_stale?
    end

    def embedding_stale?
      saved_change_to_title? || saved_change_to_description? || embedding.nil?
    end

    def announce_status_change
      ::FeatureMachine.config.on_status_change.call(self)
    end

    def enqueue_embedding
      RequestEmbeddingJob.perform_later(id)
    end
  end
end
