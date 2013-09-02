require 'spec_helper'

describe Makara2::Proxy do

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

      proxy.master_for?('select * from users')
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