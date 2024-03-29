require 'spec_helper'

describe Makara::Strategies::RoundRobin do
  let(:proxy) { FakeProxy.new({ makara: pool_config.merge(makara_config).merge(connections: []) }) }
  let(:pool) { Makara::Pool.new('test', proxy) }
  let(:pool_config) { { blacklist_duration: 5 } }
  let(:makara_config) { {} }
  let(:strategy) { pool.strategy }

  context 'default config' do
    it 'should default to the strategy' do
      expect(pool.strategy).to be_instance_of(Makara::Strategies::RoundRobin)
    end
  end

  context 'bad config' do
    let(:makara_config) { { test_strategy: 'SomethingElse::Here' } }
    it 'should raise name error' do
      expect do
        pool
      end.to raise_error(NameError)
    end
  end

  context 'given in config' do
    let(:makara_config) { { test_strategy: 'round_robin' } }
    it 'should use the strategy' do
      expect(pool.strategy).to be_instance_of(Makara::Strategies::RoundRobin)
    end
  end

  it 'should loop through with weights' do
    pool.add(pool_config) { FakeConnection.new(something: 'a') }
    pool.add(pool_config) { FakeConnection.new(something: 'b') }
    pool.add(pool_config.merge(weight: 2)) { FakeConnection.new(something: 'c') }

    expect(strategy.current.something).to eql('a')
    expect(strategy.next.something).to eql('b')
    expect(strategy.current.something).to eql('b')
    expect(strategy.current.something).to eql('b')
    expect(strategy.next.something).to eql('c')
    expect(strategy.next.something).to eql('c')
    expect(strategy.next.something).to eql('a')
  end

  it 'should handle failover to next one' do
    wrapper_a = pool.add(pool_config) { FakeConnection.new(something: 'a') }
    pool.add(pool_config) { FakeConnection.new(something: 'b') }
    pool.add(pool_config.merge(weight: 2)) { FakeConnection.new(something: 'c') }

    pool.provide do |connection|
      raise Makara::Errors::BlacklistConnection.new(wrapper_a, StandardError.new('failure')) if connection == wrapper_a
    end

    # skips a
    expect(strategy.current.something).to eql('b')
    expect(strategy.next.something).to eql('c')
    expect(strategy.next.something).to eql('c')
    expect(strategy.next.something).to eql('b')
  end
end
