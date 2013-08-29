require 'spec_helper'

describe Makara2::Pool do

  let(:pool){ Makara2::Pool.new({:blacklist_duration => 5}) }

  it 'should wrap connections with a ConnectionWrapper as theyre added to the pool' do
    expect(pool.connections).to be_empty

    wrapper = pool.add 4
    expect(pool.connections.length).to eq(1)

    expect(wrapper).to be_a(Makara2::ConnectionWrapper)
    expect(wrapper.to_i).to eq(4)
  end

  it 'should determine if its completely blacklisted' do
    
    pool.add 1
    pool.add 2

    expect(pool).not_to be_completely_blacklisted

    pool.connections.each(&:blacklist!)

    expect(pool).to be_completely_blacklisted
  end

  it 'sends methods to all underlying objects if asked to' do

    a = 'a'
    b = 'b'

    pool.add a
    pool.add b

    expect(a).to receive(:to_s).once
    expect(b).to receive(:to_s).once

    pool.send_to_all :to_s

  end

  it 'provides the next connection and blacklists' do

    a = 'a'
    b = 'b'

    wrapper_a = pool.add a
    wrapper_b = pool.add b

    allow(pool).to receive(:next).and_return(a, b)

    pool.provide do |connection|
      if connection.to_s == 'a'
        raise Makara2::Errors::BlacklistConnection(StandardError.new('failure'))
      end
    end

    expect(wrapper_a).to be_blacklisted
    expect(wrapper_b).not_to be_blacklisted

    Timecop.travel Time.now + 10 do
      expect(wrapper_a).not_to be_blacklisted
      expect(wrapper_b).not_to be_blacklisted
    end

  end

  it 'raises an error when all connections are blacklisted' do

    a = 'a'
    b = 'b'

    wrapper_a = pool.add a
    wrapper_b = pool.add b

    allow(pool).to receive(:next).and_return(a, b, nil)

    expect{
      pool.provide do |connection|
        raise Makara2::Errors::BlacklistConnection(StandardError.new('failure'))
      end
    }.to raise_error(Makara2::Errors::AllConnectionsBlacklisted)
  end

end