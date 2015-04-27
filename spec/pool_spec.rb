require 'spec_helper'

describe Makara::Pool do

  let(:proxy){ FakeProxy.new({:makara => pool_config.merge(:connections => [])}) }
  let(:pool){ Makara::Pool.new('test', proxy) }
  let(:pool_config){ {:blacklist_duration => 5} }

  it 'should wrap connections with a ConnectionWrapper as theyre added to the pool' do
    expect(pool.connections).to be_empty

    wrappera = pool.add(pool_config){ 'a' }
    wrapperb = pool.add(pool_config.merge(:weight => 2)){ 'b' }

    expect(pool.connections.length).to eq(3)

    expect(wrappera).to be_a(Makara::ConnectionWrapper)
    expect(wrappera.to_s).to eq('a')

    as, bs = pool.connections.partition{|c| c.to_s == 'a'}
    expect(as.length).to eq(1)
    expect(bs.length).to eq(2)
  end

  it 'should determine if its completely blacklisted' do

    pool.add(pool_config){ 'a' }
    pool.add(pool_config){ 'b' }

    expect(pool).not_to be_completely_blacklisted

    pool.connections.each(&:_makara_blacklist!)

    expect(pool).to be_completely_blacklisted
  end

  it 'sends methods to all underlying objects if asked to' do

    a = 'a'
    b = 'b'

    pool.add(pool_config){ a }
    pool.add(pool_config){ b }

    expect(a).to receive(:to_s).once
    expect(b).to receive(:to_s).once

    pool.send_to_all :to_s

  end

  it 'only sends methods to underlying objects which are not blacklisted' do

    a = 'a'
    b = 'b'
    c = 'c'

    pool.add(pool_config){ a }
    pool.add(pool_config){ b }
    wrapper_c = pool.add(pool_config){ c }

    expect(a).to receive(:to_s).once
    expect(b).to receive(:to_s).once
    expect(c).to receive(:to_s).never

    wrapper_c._makara_blacklist!

    pool.send_to_all :to_s

  end

  it 'provides the next connection and blacklists' do

    wrapper_a = pool.add(pool_config){ 'a' }
    wrapper_b = pool.add(pool_config){ 'b' }

    pool.provide do |connection|
      if connection.to_s == 'a'
        raise Makara::Errors::BlacklistConnection.new(StandardError.new('failure'))
      end
    end

    expect(wrapper_a._makara_blacklisted?).to eq(true)
    expect(wrapper_b._makara_blacklisted?).to eq(false)

    Timecop.travel Time.now + 10 do
      expect(wrapper_a._makara_blacklisted?).to eq(false)
      expect(wrapper_b._makara_blacklisted?).to eq(false)
    end

  end

  it 'provides the same connection if the context has not changed and the proxy is sticky' do
    allow(proxy).to receive(:sticky){ true }

    pool.add(pool_config){ 'a' }
    pool.add(pool_config){ 'b' }

    provided = []

    10.times{ pool.provide{|con| provided << con } }

    expect(provided.uniq.length).to eq(1)
  end

  it 'does not provide the same connection if the proxy is not sticky' do
    allow(proxy).to receive(:sticky){ false }

    pool.add(pool_config){ 'a' }
    pool.add(pool_config){ 'b' }

    provided = []

    10.times{ pool.provide{|con| provided << con } }

    expect(provided.uniq.length).to eq(2)
  end

  it 'raises an error when all connections are blacklisted' do

    wrapper_a = pool.add(pool_config.dup){ 'a' }
    wrapper_b = pool.add(pool_config.dup){ 'b' }

    # make the connection
    pool.send_to_all :to_s

    allow(pool).to receive(:next).and_return(wrapper_a, wrapper_b, nil)


    begin
      pool.provide do |connection|
        raise Makara::Errors::BlacklistConnection.new(connection, StandardError.new('failure'))
      end
    rescue Makara::Errors::AllConnectionsBlacklisted => e
      expect(e).to be_present
      expect(e.message).to eq("[Makara/test] All connections are blacklisted -> [Makara/test/2] failure -> [Makara/test/1] failure")
    end
  end

  it 'skips blacklisted connections when choosing the next one' do

    pool.add(pool_config){ 'a' }
    pool.add(pool_config){ 'c' }

    wrapper_b = pool.add(pool_config){ 'b' }
    wrapper_b._makara_blacklist!

    10.times{ pool.provide{|connection| expect(connection.to_s).not_to eq('b') } }

  end

end
