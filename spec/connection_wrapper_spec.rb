require 'spec_helper'

describe Makara::ConnectionWrapper do

  let(:proxy){ FakeProxy.new({:makara => {:blacklist_duration => 5, :connections => [{:role => 'master'}, {:role => 'slave'}, {:role => 'slave'}]}}) }
  let(:connection){ subject.__getobj__ }

  subject{ proxy.master_pool.connections.first }

  it 'should extend the connection with new functionality' do
    expect(connection).to respond_to(:_makara_name)
    expect(connection).to respond_to(:_makara)
    expect(connection).to respond_to(:_makara_hijack)
  end

  it 'should invoke hijacked methods on the proxy when invoked directly' do
    expect(proxy).to receive(:execute).with('test').once
    connection.execute("test")
  end

  it 'should have a default weight of 1' do
    expect(subject._makara_weight).to eq(1)
  end

  it 'should store the blacklist status' do
    expect(subject._makara_blacklisted?).to eq(false)
    subject._makara_blacklist!
    expect(subject._makara_blacklisted?).to eq(true)
    subject._makara_whitelist!
    expect(subject._makara_blacklisted?).to eq(false)
  end

end
