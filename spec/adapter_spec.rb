require 'spec_helper'

describe ActiveRecord::ConnectionAdapters::MakaraAdapter do

  class Model < ActiveRecord::Base
  end

  context "a single slave config" do

    let(:config){ dry_single_slave_config }

    before do
      connect!(config)
    end

    %w(reconnect! reset! disconnect!).each do |meth|
      it "should delegate #{meth} to all connections" do
        adapter.mcon.should_receive(meth).once
        adapter.scon(1).should_receive(meth).once
        adapter.send(meth)
      end
    end

    %w(active?).each do |meth|
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

    it 'should use the master connection if ::Makara is currently forcing it' do
      Makara.stub(:forced_to_master?).with('default').and_return(true)

      adapter.mcon.should_receive(:execute).with('insert into dogs...', nil).once
      adapter.mcon.should_receive(:execute).with('insert into cats (select * from felines)', nil).once
      adapter.mcon.should_receive(:execute).with('select * from felines', nil).once
      adapter.mcon.should_receive(:execute).with('select * from dogs', nil).once

      adapter.execute('select * from dogs')
      adapter.execute('insert into dogs...')
      adapter.execute('select * from felines')
      adapter.execute('insert into cats (select * from felines)')
    end

    context 'with sticky connections' do

      let(:config){ single_slave_config }

      it 'should tell ::Makara when a master connection is stuck to' do
        Makara.should_receive(:stick_id!).with('default').once
        adapter.execute('select * from dogs')
        adapter.execute('insert into dogs...')
      end

    end

  end

  context "a config with a makara-* adapter and a db_adapter provided" do

    let(:config){ simple_config.merge(:adapter => 'makara_mysql2') }

    it 'should invoke the makara connection with the appropriate db_adapter' do
      require 'mysql2'
      require 'active_record/connection_adapters/mysql2_adapter'

      abstract_master = Makara::ConfigParser.master_config(config)
      ActiveRecord::Base.should_receive(:mysql2_connection).and_return(ActiveRecord::Base.abstract_connection(abstract_master))
      
      connect!(config)
      ActiveRecord::Base.connection.should be_a(ActiveRecord::ConnectionAdapters::MakaraAdapter)
    end

  end

end