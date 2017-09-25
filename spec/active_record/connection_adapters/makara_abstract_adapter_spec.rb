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
    'SET @@things' => true,
    'commit' => true,
    'select * from felines' => false,
    '    select * from felines' => false,
    'select * from users for update' => true,
    '    select * from users for update' => true,
    'select * from users lock in share mode' => true,
    'select * from users where name = "for update"' => false,
    'select * from users where name = "lock in share mode"' => false,
    'select nextval(\'users_id_seq\')' => true,
    'select currval(\'users_id_seq\')' => true,
    'select lastval()' => true
  }.each do |sql, should_go_to_master|

    it "determines that \"#{sql}\" #{should_go_to_master ? 'requires' : 'does not require'} master" do
      proxy = klass.new(config(1,1))
      expect(proxy.master_for?(sql)).to eq(should_go_to_master)
    end

  end


  {
    "SET @@things" => true,
    "INSERT INTO wisdom ('The truth will set you free.')" => false,
    "INSERT INTO wisdom ('The truth will\nset you free.')" => false,
    "UPDATE dogs SET max_treats = 10 WHERE max_treats IS NULL" => false,
    %Q{
      UPDATE
        dogs
      SET
        max_treats = 10
      WHERE
        max_treats IS NULL
    } => false
  }.each do |sql, should_send_to_all_connections|

    it "determines that \"#{sql}\" #{should_send_to_all_connections ? 'should' : 'should not'} be sent to all underlying connections" do
      proxy = klass.new(config(1,1))
      proxy.master_pool.connections.each{|con| expect(con).to receive(:execute).with(sql).once}
      proxy.slave_pool.connections.each do |con|
        if should_send_to_all_connections
          expect(con).to receive(:execute).with(sql).once
        else
          expect(con).to receive(:execute).with(sql).never
        end
      end

      proxy.execute(sql)

      if should_send_to_all_connections
        expect(proxy.master_context).to be_nil
      end
    end

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
    'rollback transaction' => true,
    %Q{
      UPDATE
        dogs
      SET
        max_treats = 10
      WHERE
        max_treats IS NULL
    } => true
  }.each do |sql,should_stick|

    it "should #{should_stick ? 'stick' : 'not stick'} to master if handling sql like \"#{sql}\"" do
      proxy = klass.new(config(0,0))
      expect(proxy.would_stick?(sql)).to eq(should_stick)
    end

  end

end
