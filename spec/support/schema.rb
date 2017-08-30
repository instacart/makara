ActiveRecord::Schema.define(:version => 20130628161227) do

  if table_exists? "users"
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE users")
  else
    create_table "users" do |t|
      t.string   "name"
    end
  end

end
