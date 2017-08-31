conn = ActiveRecord::Base.connection

if conn.table_exists? "users"
  conn.execute("TRUNCATE TABLE users")
else
  conn.create_table "users" do |t|
    t.string   "name"
  end
end
