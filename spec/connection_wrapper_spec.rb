require 'spec_helper'

describe Makara::ConnectionWrapper do

  let(:proxy){ FakeProxy.new({:makara => {connections: [{role: 'master'}, {role: 'slave'}, {role: 'slave'}]}}) }
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

end
