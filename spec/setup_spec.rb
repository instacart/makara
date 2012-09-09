require 'spec_helper'

describe 'Adapter Setup and Initialization' do

  before do
    connect!(config)
  end

  context 'with no slaves configured' do
    let(:config) { simple_config }

    it 'should initialize a single master database with no slaves' do
      adapter.should be_master_only
      adapter.master.connection.class.should eql(ActiveRecord::ConnectionAdapters::AbstractAdapter)
    end

    it 'should always return the master as the correct wrapper' do
      adapter.wrapper_of_choice('SELECT * from users').should eql(adapter.master)
      adapter.wrapper_of_choice('INSERT INTO users...').should eql(adapter.master)
    end

    it 'should direct all reads and all writes to the master' do
      adapter.master.connection.should_receive(:execute).twice
      adapter.execute('SELECT * FROM users')
      adapter.execute('INSERT INTO users...')
    end

    it 'should raise exceptions immediately if an error occurs during execution' do
      adapter.master.should_receive(:execute).and_raise('Error')
      lambda{
        adapter.execute('select * from users')
      }.should raise_error
    end
  end

  context 'with one slave configured' do

    let(:config){ single_slave_config }

    it 'should initialize a single master and a single slave' do
      adapter.should_not be_master_only
      adapter.should be_slaved(1)

      adapter.slave(1).connection.class.should eql(ActiveRecord::ConnectionAdapters::AbstractAdapter)

      adapter.slave(1).name.should eql('slave1')
    end

    it 'should inherit the configuration of the master' do
      master_config = adapter.master.config
      slave_config  = adapter.slave(1).config

      slave_config.except(:name).each do |k,v|
        v.should eql(master_config[k])
      end
    end

    it 'should use the slave for reads and the master for writes' do
      adapter.wrapper_of_choice('select * from users').should eql(adapter.slave(1))
      adapter.wrapper_of_choice('select * from users').should eql(adapter.slave(1))
      adapter.wrapper_of_choice('insert into users...').should eql(adapter.master)
      adapter.wrapper_of_choice('insert into users...').should eql(adapter.master)
    end

  end

  context 'with multiple slaves configured' do

    let(:config){ multi_slave_config }

    it 'should initialize a single master and multiple slaves' do
      adapter.should_not be_master_only
      adapter.should be_slaved(2)

      [1,2].each do |num|
        adapter.slave(num).connection.class.should eql(ActiveRecord::ConnectionAdapters::AbstractAdapter)
      end

      adapter.slave(1).name.should eql('Slave One')
      adapter.slave(2).name.should eql('Slave Two')
    end

    it 'should continue to send all writes to the master but share reads between the slaves' do
      adapter.wrapper_of_choice('insert into users...').should eql(adapter.master)
      adapter.wrapper_of_choice('insert into users...').should eql(adapter.master)

      # the second one will be hit first because #next_slave starts with @slaves.first(.next)
      adapter.wrapper_of_choice('select * from users').should eql(adapter.slave(2))
      adapter.wrapper_of_choice('select * from users').should eql(adapter.slave(1))
    end

  end

  context 'with an invalid configuration' do

    let(:config){ invalid_config }

    it 'should not initialize' do
      lambda{
        adapter
      }.should raise_error(/Please install the (#{config[:db_adapter]}) adapter:/)
    end

  end

  context 'with stickiness configured' do

    context 'by default' do
      let(:config){ simple_config }

      it 'should be sticky by default' do
        adapter.should be_sticky_master
        adapter.should be_sticky_slave
      end
    end

    context 'to be on' do
      let(:config){ sticky_config }

      it 'should determine stickiness based on the database.yml' do
        adapter.should be_sticky_slaves
        adapter.should be_sticky_master
      end
    end

    context 'to be off' do
      let(:config){ dry_config }

      it 'should determine stickiness based on the database.yml' do
        adapter.should_not be_sticky_slaves
        adapter.should_not be_sticky_master
      end
    end
  end


end