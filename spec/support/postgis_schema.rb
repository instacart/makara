
ActiveRecord::Schema.define(:version => 20160518161227) do
  execute "create extension if not exists postgis"

  create_table "towns", :force => true do |t|
    t.st_point "location"
  end
end
