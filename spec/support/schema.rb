ActiveRecord::Schema.define(:version => 20130628161227) do

  drop_table "users" if table_exists? "users"

  create_table "users" do |t|
    t.string   "name"
  end

end
