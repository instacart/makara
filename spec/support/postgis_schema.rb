
ActiveRecord::Schema.define(:version => 20160518161227) do
  execute "create extension if not exists postgis"

  if table_exists? "towns"
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE towns")
  else
    create_table "towns", :force => true do |t|
      t.st_point "location"
    end
  end


end
