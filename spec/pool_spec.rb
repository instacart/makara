require 'spec_helper'

describe Makara::Pool do

  let(:proxy){ FakeProxy.new({:makara => pool_config.merge(:connections => [])}) }
  let(:pool){ Makara::Pool.new(proxy) }
  let(:pool_config){ {:blacklist_duration => 5} }

  it 'should wrap connections with a ConnectionWrapper as theyre added to the pool' do
    expect(pool.connections).to be_empty

    wrappera = pool.add 'a', pool_config
    wrapperb = pool.add 'b', pool_config.merge(:weight => 2)

    expect(pool.connections.length).to eq(3)

    expect(wrappera).to be_a(Makara::ConnectionWrapper)
    expect(wrappera.to_s).to eq('a')

    as, bs = pool.connections.partition{|c| c.to_s == 'a'}
    expect(as.length).to eq(1)
    expect(bs.length).to eq(2)
  end

  it 'should determine if its completely blacklisted' do
    
    pool.add 'a', pool_config
    pool.add 'b', pool_config

    expect(pool).not_to be_completely_blacklisted

    pool.connections.each(&:_makara_blacklist!)

    expect(pool).to be_completely_blacklisted
  end

  it 'sends methods to all underlying objects if asked to' do

    a = 'a'
    b = 'b'

    pool.add a, pool_config
    pool.add b, pool_config

    expect(a).to receive(:to_s).once
    expect(b).to receive(:to_s).once

    pool.send_to_all :to_s

  end

  it 'provides the next connection and blacklists' do

    wrapper_a = pool.add 'a', pool_config
    wrapper_b = pool.add 'b', pool_config

    pool.provide do |connection|
      if connection.to_s == 'a'
        raise Makara::Errors::BlacklistConnection.new(StandardError.new('failure'))
      end
    end

    expect(wrapper_a).to be__makara_blacklisted
    expect(wrapper_b).not_to be__makara_blacklisted

    Timecop.travel Time.now + 10 do
      expect(wrapper_a).not_to be__makara_blacklisted
      expect(wrapper_b).not_to be__makara_blacklisted
    end

  end

  it 'provides the same connection if the context has not changed and the proxy is sticky' do
    allow(proxy).to receive(:sticky){ true }

    pool.add 'a', pool_config
    pool.add 'b', pool_config

    provided = []

    10.times{ pool.provide{|con| provided << con } }

    expect(provided.uniq.length).to eq(1)
  end

  it 'does not provide the same connection if the proxy is not sticky' do
    allow(proxy).to receive(:sticky){ false }

    pool.add 'a', pool_config
    pool.add 'b', pool_config

    provided = []

    10.times{ pool.provide{|con| provided << con } }

    expect(provided.uniq.length).to eq(2)
  end

  it 'raises an error when all connections are blacklisted' do

    wrapper_a = pool.add 'a', pool_config
    wrapper_b = pool.add 'b', pool_config

    allow(pool).to receive(:next).and_return(wrapper_a, wrapper_b, nil)

    expect{
      pool.provide do |connection|
        raise Makara::Errors::BlacklistConnection.new(StandardError.new('failure'))
      end
    }.to raise_error(Makara::Errors::AllConnectionsBlacklisted)
  end

  it 'skips blacklisted connections when choosing the next one' do

    wrapper_a = pool.add 'a', pool_config
    wrapper_b = pool.add 'b', pool_config
    wrapper_c = pool.add 'c', pool_config

    wrapper_b._makara_blacklist!

    10.times{ pool.provide{|connection| expect(connection.to_s).not_to eq('b') } }

  end

end