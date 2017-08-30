ActiveRecord::Schema.define(:version => 20130628161227) do

  begin
    drop_table "users" if table_exists? "users"
  rescue Exception => e
    puts "#{e.message}\n\t#{e.backtrace.join("\n\t")}"
  end

  create_table "users" do |t|
    t.string   "name"
  end

end
