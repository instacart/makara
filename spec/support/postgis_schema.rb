
ActiveRecord::Schema.define(:version => 20160518161227) do
  execute "create extension if not exists postgis"

  begin
    drop_table "towns" if table_exists? "towns"
  rescue Exception => e
    puts "#{e.message}\n\t#{e.backtrace.join("\n\t")}"
  end

  create_table "towns", :force => true do |t|
    t.st_point "location"
  end
end
