conn = ActiveRecord::Base.connection

conn.execute "create extension if not exists postgis"

if conn.table_exists? "towns"
  conn.execute("TRUNCATE TABLE towns")
else
  conn.create_table "towns", :force => true do |t|
    t.st_point "location"
  end
end
