ActiveRecord::Schema.define(version: 20130628161227) do
  create_table :users, force: true do |t|
    t.string   :name
  end

  create_table :pictures, force: true do |t|
    t.string  :name
    t.integer :imageable_id
    t.string  :imageable_type
    t.timestamps null: false
  end

  add_index :pictures, :imageable_id
end
