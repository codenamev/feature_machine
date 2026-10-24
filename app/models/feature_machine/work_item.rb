# A buildable unit: what nowreading.dev will actually build or fix, written
# by an admin from one or more FeatureRequests. The requests are the evidence;
# the work item is the scoped, hand-off-ready specification.
#
# Drafts are private to admins. Planned, in-progress and shipped items are on
# /roadmap for signed-in users, and a work item's status is pushed down to the
# requests bucketed into it.
#
# `in_review` is the hand-back: whoever built it has opened a pull request and
# is waiting on the maintainer. Users never see it; to them the work is still
# in progress until it ships.
module FeatureMachine
  class WorkItem < ApplicationRecord
    self.table_name = "work_items"

    # Phase 2 keeps the public surface unchanged: params keys, dom_id,
    # polymorphic route helpers and i18n keys all still read `work_item`.
    def self.model_name
      @_model_name ||= ActiveModel::Name.new(self, nil, "WorkItem")
    end

    has_many :feature_requests, class_name: "FeatureMachine::Request", dependent: nil
    has_many :outgoing_relations, class_name: "FeatureMachine::WorkItemRelation", foreign_key: :from_work_item_id, dependent: :destroy
    has_many :incoming_relations, class_name: "FeatureMachine::WorkItemRelation", foreign_key: :to_work_item_id,   dependent: :destroy

    enum :kind, { feature: 0, bug: 1 }, validate: true
    enum :status, { draft: 0, planned: 1, in_progress: 2, shipped: 3, declined: 4, in_review: 5 }, validate: true

    has_neighbors :embedding

    # What the admin list shows first: what is waiting on the maintainer
    # (reviews, then drafts needing a spec), then live work.
    ADMIN_ORDER = %w[in_review draft in_progress planned shipped declined].freeze
    # Statuses the roadmap lists as upcoming, in display order.
    UPCOMING = %w[in_progress planned].freeze
    SIMILARITY_THRESHOLD = 0.5
    GITHUB = "https://github.com/".freeze
    PULL_REQUEST_URL = %r{\A#{GITHUB}(?<path>[\w.-]+/[\w.-]+/pull/(?<number>\d+))\z}

    # What a maintainer's agent may do to a work item's status. Approving a
    # draft (draft -> planned) and declining are triage, and triage is human.
    AGENT_TRANSITIONS = {
      "planned" => %w[in_progress],
      "in_progress" => %w[planned in_review shipped],
      "in_review" => %w[in_progress shipped]
    }.freeze

    InvalidTransition = Class.new(StandardError)

    validates :title, presence: true, length: { minimum: 8, maximum: 120 }
    validates :problem, :scope, :acceptance_criteria, length: { maximum: 5000 }
    validates :summary, length: { maximum: 600 }
    validates :progress_note, length: { maximum: 1000 }
    # The summary is what users read; nothing goes on the roadmap without one.
    validates :summary, presence: { message: "is required before this goes on the roadmap" }, if: :on_roadmap?
    validates :pull_request_url, format: { with: PULL_REQUEST_URL, message: "must be a GitHub pull request URL, like https://github.com/owner/repo/pull/123" }, allow_blank: true
    # Asking for review without saying where the work is helps nobody.
    validates :pull_request_url, presence: { message: "is required to ask for review" }, if: :in_review?

    scope :embedded,     -> { where.not(embedding: nil) }
    scope :active,       -> { where(status: %i[draft planned in_progress in_review]) }
    scope :upcoming,     -> { where(status: UPCOMING + %w[in_review]) }
    scope :newest_first, -> { order(created_at: :desc) }
    scope :changelog,    -> { shipped.order(shipped_at: :desc) }

    before_save :stamp_shipped_at
    after_save :push_status_to_requests, if: -> { saved_change_to_status? || saved_change_to_progress_note? }
    before_destroy :release_requests
    after_commit :enqueue_embedding, on: [ :create, :update ], if: :embedding_wanted?

    # Planned, underway or shipped: visible on /roadmap.
    def on_roadmap?
      planned? || in_progress? || in_review? || shipped?
    end

    # The status users see. Review is between the builder and the maintainer.
    def public_status
      in_review? ? "in_progress" : status
    end

    # "owner/repo/pull/123", or nil unless the stored URL really is a GitHub
    # pull request. Views build the link from this and the fixed GitHub origin,
    # so a URL that slipped past validation can never become an href.
    def pull_request_path
      pull_request_url.to_s.match(PULL_REQUEST_URL)&.[](:path)
    end

    # "#123"
    def pull_request_number
      pull_request_url.to_s.match(PULL_REQUEST_URL)&.[](:number)&.prepend("#")
    end

    # The public state a request takes on when it is bucketed into this item.
    # A draft is not a commitment, so its requests still read as `requested`.
    def request_attributes
      { status: draft? ? "requested" : public_status, progress_note: progress_note, shipped_at: shipped_at }
    end

    # Ranking signal: distinct people who asked, not raw request count.
    def requesters_count
      feature_requests.distinct.count(:user_id)
    end

    def relations
      WorkItemRelation.involving(self).includes(:from_work_item, :to_work_item)
    end

    # Work items nearest in embedding space that aren't already linked: the
    # graph edges an admin hasn't drawn yet.
    def similar(limit: 3)
      return [] if embedding.blank?

      linked_ids = relations.flat_map { |relation| [ relation.from_work_item_id, relation.to_work_item_id ] }
      WorkItem.embedded
        .where.not(id: [ id, *linked_ids ])
        .nearest_neighbors(:embedding, embedding, distance: "cosine")
        .limit(limit)
        .select { |item| 1.0 - item.neighbor_distance.to_f >= SIMILARITY_THRESHOLD }
    end

    # Moves an approved work item along on an agent's behalf: pick up
    # (planned -> in_progress), hand back for review, put back, or ship. Locked
    # so two agents can't both pick up the same item. `changes` are saved with
    # the move, so a pull request URL arrives together with `in_review`.
    def agent_transition!(new_status, changes = {})
      with_lock do
        allowed = AGENT_TRANSITIONS.fetch(status, [])
        unless allowed.include?(new_status.to_s)
          raise InvalidTransition, "Cannot move from #{status} to #{new_status}. From #{status} an agent may move to: #{allowed.to_sentence.presence || 'nothing'}."
        end

        update!(changes.to_h.merge(status: new_status))
      end
    end

    # Problem and acceptance criteria are the minimum someone else needs to
    # pick this up without asking questions.
    def handoff_ready?
      problem.present? && acceptance_criteria.present?
    end

    private

    def stamp_shipped_at
      self.shipped_at ||= Time.current if shipped? && (new_record? || will_save_change_to_status?)
    end

    def push_status_to_requests
      feature_requests.update_all(request_attributes.merge(updated_at: Time.current))
    end

    def release_requests
      feature_requests.update_all(work_item_id: nil, status: "requested", progress_note: nil, shipped_at: nil, updated_at: Time.current)
    end

    def embedding_wanted?
      ::FeatureMachine.config.embeddings? && embedding_stale?
    end

    def embedding_stale?
      saved_change_to_title? || saved_change_to_summary? || saved_change_to_problem? || saved_change_to_scope? || embedding.nil?
    end

    def enqueue_embedding
      WorkItemEmbeddingJob.perform_later(id)
    end
  end
end
