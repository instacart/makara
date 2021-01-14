require 'spec_helper'

describe Makara::Proxy do

  let(:klass){ FakeProxy }


  it 'sets up a master and replica pool no matter the number of connections' do
    proxy = klass.new(config(0, 0))
    expect(proxy.master_pool).to be_a(Makara::Pool)
    expect(proxy.replica_pool).to be_a(Makara::Pool)

    proxy = klass.new(config(2, 0))
    expect(proxy.master_pool).to be_a(Makara::Pool)
    expect(proxy.replica_pool).to be_a(Makara::Pool)

    proxy = klass.new(config(0, 2))
    expect(proxy.master_pool).to be_a(Makara::Pool)
    expect(proxy.replica_pool).to be_a(Makara::Pool)

    proxy = klass.new(config(2, 2))
    expect(proxy.master_pool).to be_a(Makara::Pool)
    expect(proxy.replica_pool).to be_a(Makara::Pool)
  end


  it 'instantiates N connections within each pool' do
    proxy = klass.new(config(1, 2))

    expect(proxy.master_pool.connection_count).to eq(1)
    expect(proxy.replica_pool.connection_count).to eq(2)
  end

  it 'should delegate any unknown method to a connection in the master pool' do
    proxy = klass.new(config(1, 2))

    con = proxy.master_pool.connections.first
    allow(con).to receive(:irespondtothis){ 'hello!' }

    expect(proxy).to respond_to(:irespondtothis)
    expect(proxy.irespondtothis).to eq('hello!')
  end

  describe '#stick_to_master' do
    let(:proxy) { klass.new(config(1, 2)) }

    it 'should use master if manually forced' do
      expect(proxy.master_for?('select * from users')).to eq(false)

      proxy.stick_to_master!

      expect(proxy.master_for?('select * from users')).to eq(true)
    end

    it 'should persist stickiness by default' do
      now = Time.now
      proxy.stick_to_master!

      next_context = Makara::Context.next
      expect(next_context[proxy.id]).to be >= (now + 5).to_f

      proxy = klass.new(config(1, 2))
      expect(proxy.master_for?('select * from users')).to eq(true)
    end

    it 'optionally skips stickiness persistence, so it applies only to the current request' do
      now = Time.now
      proxy.stick_to_master!(false)

      expect(proxy.master_for?('select * from users')).to eq(true)
      next_context = Makara::Context.next
      expect(next_context).to be_nil # Nothing to persist, so context is empty

      proxy = klass.new(config(1, 2))
      expect(proxy.master_for?('select * from users')).to eq(false)
    end

    it 'supports a float master_ttl for stickiness duration' do
      now = Time.now
      config = config(1, 2).dup
      config[:makara][:master_ttl] = 0.5
      proxy = klass.new(config)

      proxy.stick_to_master!

      next_context = Makara::Context.next
      expect(next_context[proxy.id]).to be >= (now + 0.5).to_f
      expect(next_context[proxy.id]).to be < (now + 1).to_f
    end
  end


  describe '#appropriate_pool' do
    let(:proxy) { klass.new(config(1,1)) }

    it 'should be sticky by default' do
      expect(proxy.sticky).to eq(true)
    end

    it 'should provide the replica pool for a read' do
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

    it 'should not stick to master if stickiness is disabled' do
      proxy.sticky = false
      expect(proxy.master_for?('insert into users values (a,b,c)')).to eq(true)
      expect(proxy.master_for?('select * from users')).to eq(false)
    end

    it 'should not stick to master if we are in a without_sticking block' do
      expect(proxy.master_for?('insert into users values (a,b,c)')).to eq(true)

      proxy.without_sticking do
        expect(proxy.master_for?('insert into users values (a,b,c)')).to eq(true)
        expect(proxy.master_for?('select * from users')).to eq(false)
      end

      expect(proxy.master_for?('select * from users')).to eq(true)
      expect(proxy.master_for?('insert into users values (a,b,c)')).to eq(true)
      expect(proxy.master_for?('select * from users')).to eq(true)
    end

    it 'should not stick to master after without_sticking block if there is a write in it' do
      expect(proxy.master_for?('select * from users')).to eq(false)

      proxy.without_sticking do
        expect(proxy.master_for?('insert into users values (a,b,c)')).to eq(true)
        expect(proxy.master_for?('select * from users')).to eq(false)
      end

      expect(proxy.master_for?('select * from users')).to eq(false)
    end

    it "should not release master if it was stuck in the same request (no context changes yet)" do
      expect(proxy.master_for?('insert into users values (a,b,c)')).to eq(true)
      expect(proxy.master_for?('select * from users')).to eq(true)

      Timecop.travel Time.now + 10 do
        # master_ttl has passed but we are still in the same request, so current context
        # is still relevant
        expect(proxy.master_for?('select * from users')).to eq(true)
      end
    end

    it 'should release master if all stuck connections are released' do
      expect(proxy.master_for?('insert into users values (a,b,c)')).to eq(true)
      expect(proxy.master_for?('select * from users')).to eq(true)

      Makara::Context.release_all

      expect(proxy.master_for?('select * from users')).to eq(false)
    end

    it 'should use master if all replicas are blacklisted' do
      allow(proxy.replica_pool).to receive(:completely_blacklisted?){ true }
      expect(proxy.master_for?('select * from users')).to eq(true)
    end

    it 'should use master if all replicas become blacklisted as part of the invocation' do
      allow(proxy.replica_pool).to receive(:next).and_return(nil)

      test = double
      expect(test).to receive(:blacklisting).once
      expect(test).to receive(:using_master).once

      proxy.send(:appropriate_pool, :execute, ['select * from users']) do |pool|
        if pool == proxy.replica_pool
          test.blacklisting
          pool.instance_variable_get('@blacklist_errors') << StandardError.new('some connection issue')
          pool.connections.each(&:_makara_blacklist!)
          pool.provide
        else
          test.using_master
        end
      end
    end

    it 'should raise the error and whitelist all connections if everything is blacklisted (start over)' do
      proxy.ping

      # weird setup to allow for the correct
      proxy.replica_pool.connections.each(&:_makara_blacklist!)
      proxy.replica_pool.instance_variable_get('@blacklist_errors') << StandardError.new('some replica connection issue')
      proxy.master_pool.connections.each(&:_makara_blacklist!)
      proxy.master_pool.instance_variable_get('@blacklist_errors') << StandardError.new('some master connection issue')

      allow(proxy).to receive(:_appropriate_pool).and_return(proxy.replica_pool, proxy.master_pool)

      begin
        proxy.send(:appropriate_pool, :execute, ['select * from users']) do |pool|
          pool.provide{|c| c }
        end
      rescue Makara::Errors::AllConnectionsBlacklisted => e
        expect(e.message).to eq('[Makara/master] All connections are blacklisted -> some master connection issue -> [Makara/replica] All connections are blacklisted -> some replica connection issue')
      end

      proxy.replica_pool.connections.each{|con| expect(con._makara_blacklisted?).to eq(false) }
      proxy.master_pool.connections.each{|con| expect(con._makara_blacklisted?).to eq(false) }
    end
  end
end
