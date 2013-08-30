require 'spec_helper'

describe Makara2::ConnectionProxy::Base do

  def change_context
    Makara2::Context.set_previous Makara2::Context.get_current
    Makara2::Context.set_current Makara2::Context.generate
  end



  let(:klass){ FakeProxy }


  it 'sets up a master and slave pool no matter the number of connections' do
    proxy = klass.new(config(0,0))
    expect(proxy.master_pool).to be_a(Makara2::Pool)
    expect(proxy.slave_pool).to be_a(Makara2::Pool)

    proxy = klass.new(config(2,0))
    expect(proxy.master_pool).to be_a(Makara2::Pool)
    expect(proxy.slave_pool).to be_a(Makara2::Pool)

    proxy = klass.new(config(0,2))
    expect(proxy.master_pool).to be_a(Makara2::Pool)
    expect(proxy.slave_pool).to be_a(Makara2::Pool)

    proxy = klass.new(config(2,2))
    expect(proxy.master_pool).to be_a(Makara2::Pool)
    expect(proxy.slave_pool).to be_a(Makara2::Pool)
  end


  it 'instantiates N connections within each pool' do
    proxy = klass.new(config(1,2))

    expect(proxy.master_pool.connection_count).to eq(1)
    expect(proxy.slave_pool.connection_count).to eq(2)
  end

  it 'should delegate any unknown method to a connection in the master pool' do
    proxy = klass.new(config(1,2))

    con = proxy.master_pool.connections.first
    allow(con).to receive(:irespondtothis){ 'hello!' }

    expect(proxy).to respond_to(:irespondtothis)
    expect(proxy.irespondtothis).to eq('hello!')
  end


  {
    "insert into dogs..." => true,
    "insert into cats (select * from felines)" => true,
    "savepoint active_record_1" => true,
    "begin" => true,
    "rollback" => true,
    "update users set" => true,
    "delete from people" => true,
    "release savepoint" => true,
    "show tables" => true,
    "show fields" => true,
    "describe table" => true,
    "show index" => true,
    "set @@things" => true,
    "commit" => true,
    "select * from felines" => false
  }.each do |sql, should_go_to_master|

    it "determines if \"#{sql}\" #{should_go_to_master ? 'requires' : 'does not require'} master" do
      proxy = klass.new(config(1,1))
      expect(proxy.master_for?(sql)).to eq(should_go_to_master)
    end

  end


  it 'should send SET operations to all underlying connections' do
    proxy = klass.new(config(1,1))
    expect(proxy.master_pool).to receive(:send_to_all).with(:query, 'SET @@things').once
    expect(proxy.slave_pool).to receive(:send_to_all).with(:query, 'SET @@things').once

    proxy.query("SET @@things")

    expect(proxy.master_context).to be_nil
  end


  {
    "show full tables" => false,
    "show full table" => false,
    "show index" => false,
    "show indexes" => false,
    "describe stuff" => false,
    "explain things" => false,
    "show database" => false,
    "show schema" => false,
    "show view" => false,
    "show views" => false,
    "show table" => false,
    "show tables" => false,
    "set @@things" => false,
    "update users" => true,
    "insert into" => true,
    "delete from" => true,
    "begin transaction" => true,
    "begin deferred transaction" => true,
    "commit transaction" => true,
    "rollback transaction" => true
  }.each do |sql,should_stick|

    it "should #{should_stick ? 'stick' : 'not stick'} to master if handling sql like \"#{sql}\"" do
      proxy = klass.new(config(0,0))
      expect(proxy.would_stick?(sql)).to eq(should_stick)
    end

  end


  context "#appropriate_pool" do

    let(:proxy){ klass.new(config(1,1)) }

    it 'should provide the slave pool for a read' do
      expect(proxy.master_for?('select * from users')).to eq(false)
    end

    it 'should provide the master pool for a write' do
      expect(proxy.master_for?('insert into users values (a,b,c)')).to eq(true)
    end

    # master is used, it should continue being used for the duration of the context
    it 'should stick to master once used for a sticky operation' do
      expect(proxy.master_for?('insert into users values (a,b,c)')).to eq(true)
      expect(proxy.master_for?('select * from users')).to eq(true)
    end

    # if the context changes we should still use master until the previous context is no longer relevant
    it 'should release master if the context changes and enough time passes' do
      expect(proxy.master_for?('insert into users values (a,b,c)')).to eq(true)
      expect(proxy.master_for?('select * from users')).to eq(true)

      change_context

      Timecop.travel Time.now + 10 do
        expect(proxy.master_for?('select * from users')).to eq(false)
      end
    end

    it 'should not release master if the previous context is still relevant' do
      expect(proxy.master_for?('insert into users values (a,b,c)')).to eq(true)
      expect(proxy.master_for?('select * from users')).to eq(true)

      change_context

      expect(proxy.master_for?('select * from users')).to eq(true)

      Timecop.travel Time.now + 10 do
        # cache is expired but context has not changed
        expect(proxy.master_for?('select * from users')).to eq(true)

        change_context

        expect(proxy.master_for?('select * from users')).to eq(false)
      end
    end

    it 'should release master if context changes enough' do
      expect(proxy.master_for?('insert into users values (a,b,c)')).to eq(true)
      change_context
      change_context
      expect(proxy.master_for?('select * from users')).to eq(false)
    end

    it 'should use master if all slaves are blacklisted' do
      allow(proxy.slave_pool).to receive(:completely_blacklisted?){ true }
      expect(proxy.master_for?('select * from users')).to eq(true)
    end

  end



end