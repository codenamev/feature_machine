class CreateFeatureRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      # requested 0, planned 1, in_progress 2, shipped 3, declined 4 (FeatureRequest#status)
      t.integer :status, null: false, default: 0
      # Public progress note the maintainer writes when the status moves.
      t.text :progress_note
      t.datetime :shipped_at

      t.timestamps
    end

    add_index :feature_requests, [ :status, :created_at ]
  end
end
