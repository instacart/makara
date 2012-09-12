require 'spec_helper'


describe 'Makara Connection Decoration' do

  before do
    connect!(config)
  end

  let(:config){ simple_config }
  let(:con){ adapter.mcon }

  it 'should integrate with the underlying adapters, giving reference to the makara adapter' do
    con.should respond_to(:with_makara)
    con.should respond_to(:makara_adapter=)

    con.instance_variable_get('@makara_adapter').should eql(adapter)
  end

  describe '#with_makara' do

    it 'should return the makara adapter if we haven\'t hijacked the execution yet' do
      con.with_makara do |acceptor|
        acceptor.should eql(adapter)
      end
    end

    it 'should return nil if we\'ve already hijacked the execution' do      
      adapter.send(:hijacking!) do
        con.with_makara do |acceptor|
          acceptor.should be_nil
        end
      end
    end

  end

  it 'should invoke the makara adapter when execute is called internally' do
    adapter.should_receive(:execute).with('select * from users').once
    con.execute('select * from users')
  end

end