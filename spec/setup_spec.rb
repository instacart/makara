require 'spec_helper'

describe 'Adapter Setup and Initialization' do

  let(:adapter){ ActiveRecord::Base.makara_connection(config) }

  context 'with no slaves configured' do
    let(:config) { simple_config }

    it 'should initialize a single master database with no slaves' do
      
      adapter.should be_master_only
      adapter.master.should be_a(Makara::ConnectionWrapper::MasterWrapper)
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


end