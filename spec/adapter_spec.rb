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

end