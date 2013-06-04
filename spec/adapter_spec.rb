require 'spec_helper'

describe ActiveRecord::ConnectionAdapters::MakaraAdapter do

  before do
    connect!(config)
  end

  let(:config){ dry_single_slave_config }

  ActiveRecord::ConnectionAdapters::MakaraAdapter::MASS_DELEGATION_METHODS.each do |meth|
    it "should delegate #{meth} to all connections" do
      adapter.mcon.should_receive(meth).once
      adapter.scon(1).should_receive(meth).once
      adapter.send(meth)
    end
  end

  ActiveRecord::ConnectionAdapters::MakaraAdapter::MASS_ANY_DELEGATION_METHODS.each do |meth|
    it "should delegate and evaluate an any? on #{meth}" do
      adapter.mcon.should_receive(meth).once
      adapter.scon(1).should_receive(meth).once
      adapter.send(meth)
    end
  end

  it 'should use the correct wrapper' do

    adapter.mcon.should_receive(:execute).with('insert into dogs...', nil).once
    adapter.mcon.should_receive(:execute).with('insert into cats (select * from felines)', nil).once
    adapter.scon.should_receive(:execute).with('select * from felines', nil).once
    adapter.scon.should_receive(:execute).with('select * from dogs', nil).once

    adapter.execute('select * from dogs')
    adapter.execute('insert into dogs...')
    adapter.execute('select * from felines')
    adapter.execute('insert into cats (select * from felines)')

  end

  describe 'establishing connections' do
    let(:base_config) { {:adapter => 'abstract', :database => 'test_db', :host => 'localhost', :port => '3439'} }
    let(:master_config) { base_config.merge({:name => 'master', :role => 'master'}) }
    let(:slave_config) { base_config.merge({:name => 'slave1'}) }

    context 'when a slave is down' do
      it 'skips the slave without an error' do
        ActiveRecord::Base.should_receive(:abstract_connection).with(master_config).and_call_original
        ActiveRecord::Base.should_receive(:abstract_connection).with(slave_config).and_raise(ActiveRecord::ConnectionNotEstablished)
        expect { ActiveRecord::Base.makara_connection(config) }.not_to raise_error
      end
    end

    context 'when a master is down' do
      it 'raises error from connection attempt' do
        ActiveRecord::Base.should_receive(:abstract_connection).with(master_config).and_raise(ActiveRecord::ConnectionNotEstablished)
        ActiveRecord::Base.should_receive(:abstract_connection).with(slave_config).never
        expect { ActiveRecord::Base.makara_connection(config) }.to raise_error(ActiveRecord::ConnectionNotEstablished)
      end
    end
  end

end
