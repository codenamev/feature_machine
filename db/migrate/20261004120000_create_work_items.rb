# Splits "what a user asked for" (feature_requests, now also bug reports) from
# "what we will build" (work_items). Requests are bucketed into work items by
# an admin during triage; work items relate to one another as a graph.
class CreateWorkItems < ActiveRecord::Migration[8.1]
  def change
    create_table :work_items do |t|
      t.string :title, null: false
      # feature 0, bug 1 (WorkItem#kind)
      t.integer :kind, null: false, default: 0
      # draft 0, planned 1, in_progress 2, shipped 3, declined 4 (WorkItem#status)
      t.integer :status, null: false, default: 0
      # The hand-off spec.
      t.text :problem
      t.text :scope
      t.text :acceptance_criteria
      # Public: the one-paragraph roadmap/changelog entry and the progress note.
      t.text :summary
      t.text :progress_note
      t.datetime :shipped_at
      t.vector :embedding, limit: 1536
      t.datetime :embedded_at
      t.string :embedding_input_digest

      t.timestamps
    end
    add_index :work_items, [ :status, :shipped_at ]

    create_table :work_item_relations do |t|
      t.references :from_work_item, null: false, foreign_key: { to_table: :work_items }
      t.references :to_work_item, null: false, foreign_key: { to_table: :work_items }
      t.string :kind, null: false, default: "related"

      t.timestamps
    end
    add_index :work_item_relations, [ :from_work_item_id, :to_work_item_id, :kind ],
              unique: true, name: "index_work_item_relations_uniqueness"

    change_table :feature_requests do |t|
      # feature 0, bug 1 (FeatureRequest#kind)
      t.integer :kind, null: false, default: 0
      t.references :work_item, foreign_key: true
      t.datetime :embedded_at
      t.string :embedding_input_digest
    end
    add_column :feature_requests, :embedding, :vector, limit: 1536

    add_column :users, :admin, :boolean, null: false, default: false
  end
end
