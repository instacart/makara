require 'spec_helper'
require 'active_record/connection_adapters/makara_abstract_adapter'

describe ActiveRecord::ConnectionAdapters::MakaraAbstractAdapter do

  let(:klass){ FakeAdapter }

  {
    'insert into dogs...' => true,
    'insert into cats (select * from felines)' => true,
    'savepoint active_record_1' => true,
    'begin' => true,
    'rollback' => true,
    'update users set' => true,
    'delete from people' => true,
    'release savepoint' => true,
    'show tables' => true,
    'show fields' => true,
    'describe table' => true,
    'show index' => true,
    'set @@things' => true,
    'commit' => true,
    'select * from felines' => false,
    'select * from users for update' => true,
    'select * from users lock in share mode' => true,
    'select * from users where name = "for update"' => false,
    'select * from users where name = "lock in share mode"' => false
  }.each do |sql, should_go_to_master|

    it "determines if \"#{sql}\" #{should_go_to_master ? 'requires' : 'does not require'} master" do
      proxy = klass.new(config(1,1))
      expect(proxy.master_for?(sql)).to eq(should_go_to_master)
    end

  end



  it 'should send SET operations to all underlying connections' do
    proxy = klass.new(config(1,1))
    proxy.master_pool.connections.each{|con| expect(con).to receive(:execute).with('SET @@things').once }
    proxy.slave_pool.connections.each{|con| expect(con).to receive(:execute).with('SET @@things').once }

    proxy.execute("SET @@things")

    expect(proxy.master_context).to be_nil
  end

  {
    'show full tables' => false,
    'show full table' => false,
    'show index' => false,
    'show indexes' => false,
    'describe stuff' => false,
    'explain things' => false,
    'show database' => false,
    'show schema' => false,
    'show view' => false,
    'show views' => false,
    'show table' => false,
    'show tables' => false,
    'set @@things' => false,
    'update users' => true,
    'insert into' => true,
    'delete from' => true,
    'begin transaction' => true,
    'begin deferred transaction' => true,
    'commit transaction' => true,
    'rollback transaction' => true
  }.each do |sql,should_stick|

    it "should #{should_stick ? 'stick' : 'not stick'} to master if handling sql like \"#{sql}\"" do
      proxy = klass.new(config(0,0))
      expect(proxy.would_stick?(sql)).to eq(should_stick)
    end

  end

end
