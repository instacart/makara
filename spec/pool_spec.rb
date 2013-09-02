require 'spec_helper'

describe Makara2::Pool do

  let(:proxy){ FakeProxy.new({makara: pool_config.merge(connections: [])}) }
  let(:pool){ Makara2::Pool.new(proxy) }
  let(:pool_config){ {:blacklist_duration => 5} }

  it 'should wrap connections with a ConnectionWrapper as theyre added to the pool' do
    expect(pool.connections).to be_empty

    wrapper = pool.add 'a', pool_config
    expect(pool.connections.length).to eq(1)

    expect(wrapper).to be_a(Makara2::ConnectionWrapper)
    expect(wrapper.to_s).to eq('a')
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

    Timecop.freeze

    wrapper_a = pool.add 'a', pool_config
    wrapper_b = pool.add 'b', pool_config

    allow(pool).to receive(:next).and_return(wrapper_a, wrapper_b)

    pool.provide do |connection|
      if connection.to_s == 'a'
        raise Makara2::Errors::BlacklistConnection.new(StandardError.new('failure'))
      end
    end

    expect(wrapper_a).to be__makara_blacklisted
    expect(wrapper_b).not_to be__makara_blacklisted

    Timecop.travel Time.now + 10 do
      expect(wrapper_a).not_to be__makara_blacklisted
      expect(wrapper_b).not_to be__makara_blacklisted
    end

  end

  it 'raises an error when all connections are blacklisted' do

    wrapper_a = pool.add 'a', pool_config
    wrapper_b = pool.add 'b', pool_config

    allow(pool).to receive(:next).and_return(wrapper_a, wrapper_b, nil)

    expect{
      pool.provide do |connection|
        raise Makara2::Errors::BlacklistConnection.new(StandardError.new('failure'))
      end
    }.to raise_error(Makara2::Errors::AllConnectionsBlacklisted)
  end

  it 'skips blacklisted connections when choosing the next one' do

    wrapper_a = pool.add 'a', pool_config
    wrapper_b = pool.add 'b', pool_config
    wrapper_c = pool.add 'c', pool_config

    wrapper_b._makara_blacklist!

    10.times{ pool.provide{|connection| expect(connection.to_s).not_to eq('b') } }

  end

end