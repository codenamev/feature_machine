ActiveRecord::Schema[8.1].define(version: 1) do
  enable_extension "vector"

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "handle", null: false
    t.timestamps
  end
end
