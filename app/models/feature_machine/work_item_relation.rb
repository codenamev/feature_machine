# An edge in the work-item graph: how two buildable units relate. Mirrors
# Connection for articles, but the vocabulary is about delivery order and
# containment rather than ideas.
module FeatureMachine
  class WorkItemRelation < ApplicationRecord
    self.table_name = "work_item_relations"

    # Phase 2 keeps the public surface unchanged: params keys, dom_id,
    # polymorphic route helpers and i18n keys all still read `work_item_relation`.
    def self.model_name
      @_model_name ||= ActiveModel::Name.new(self, nil, "WorkItemRelation")
    end

    # kind => [ label read from the "from" side, label read from the "to" side ]
    KINDS = {
      "related" => [ "is related to", "is related to" ],
      "blocks"  => [ "blocks", "is blocked by" ],
      "part_of" => [ "is part of", "includes" ]
    }.freeze

    belongs_to :from_work_item, class_name: "FeatureMachine::WorkItem"
    belongs_to :to_work_item,   class_name: "FeatureMachine::WorkItem"

    validates :kind, inclusion: { in: KINDS.keys }
    validates :from_work_item_id, uniqueness: { scope: [ :to_work_item_id, :kind ], message: "is already linked that way" }
    validate :endpoints_must_differ

    before_validation :canonicalize_symmetric_endpoints

    scope :involving, ->(item) { where("from_work_item_id = :id OR to_work_item_id = :id", id: item.id) }

    def symmetric?
      KINDS.fetch(kind).uniq.one?
    end

    def counterpart_of(item)
      item.id == from_work_item_id ? to_work_item : from_work_item
    end

    # The relation as read from `item`'s side: "blocks" or "is blocked by".
    def label_for(item)
      forward, inverse = KINDS.fetch(kind)
      item.id == from_work_item_id ? forward : inverse
    end

    private

    # A symmetric edge is stored low id -> high id so A~B and B~A collide on
    # the unique index instead of both existing.
    def canonicalize_symmetric_endpoints
      return unless KINDS.key?(kind) && symmetric? && from_work_item_id && to_work_item_id
      return if from_work_item_id <= to_work_item_id

      self.from_work_item_id, self.to_work_item_id = to_work_item_id, from_work_item_id
    end

    def endpoints_must_differ
      errors.add(:to_work_item_id, "must be a different work item") if from_work_item_id.present? && from_work_item_id == to_work_item_id
    end
  end
end
