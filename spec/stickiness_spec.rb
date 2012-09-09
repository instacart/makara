require 'spec_helper'

describe 'Makara Adapter Stickiness' do

  before do
    connect!(config)
    stub_all_connections!
  end

  let(:config){ multi_slave_config }

  it 'should stick to a slave once it\'s used' do

    adapter.scon(1).should_receive(:execute).with('insert into chairs...', nil).never
    adapter.scon(2).should_receive(:execute).with('insert into chairs...', nil).never

    adapter.mcon.should_receive(:execute).with('insert into chairs...', nil).twice

    adapter.scon(1).should_receive(:execute).with('select * from users', nil).never
    adapter.scon(2).should_receive(:execute).with('select * from users', nil).once
    adapter.scon(1).should_receive(:execute).with('select * from admins', nil).never
    adapter.scon(2).should_receive(:execute).with('select * from admins', nil).once

    adapter.execute('select * from users')
    adapter.execute('select * from admins')
    adapter.execute('insert into chairs...')

    adapter.unstick!

    adapter.scon(1).should_receive(:execute).with('select * from cars', nil).once
    adapter.scon(2).should_receive(:execute).with('select * from cars', nil).never
    adapter.scon(1).should_receive(:execute).with('select * from trucks', nil).once
    adapter.scon(2).should_receive(:execute).with('select * from trucks', nil).never

    adapter.execute('select * from cars')
    adapter.execute('select * from trucks')
    adapter.execute('insert into chairs...')
  end

  it 'should stick to master even if sticky slaves are present' do

    adapter.scon(1).should_receive(:execute).never
    adapter.scon(2).should_receive(:execute).with('select * from users', nil).once
    adapter.scon(2).should_receive(:execute).with('select * from cars', nil).never
    adapter.mcon.should_receive(:execute).with('insert into cars...', nil).once
    adapter.mcon.should_receive(:execute).with('select * from cars', nil).twice

    adapter.execute('select * from users')
    adapter.execute('insert into cars...')
    adapter.execute('select * from cars')
    adapter.execute('select * from cars')

  end

  context 'with a dry master' do
    
    let(:config){ multi_slave_config.merge(:sticky_master => false) }
    
    it 'should return to the sticky slave if the master is not sticky' do
      adapter.scon(1).should_receive(:execute).never
      adapter.scon(2).should_receive(:execute).with('select * from users', nil).once
      adapter.mcon.should_receive(:execute).with('select * from cars', nil).never
      adapter.mcon.should_receive(:execute).with('insert into cars...', nil).once
      adapter.scon(2).should_receive(:execute).with('select * from cars', nil).twice

      adapter.execute('select * from users')
      adapter.execute('insert into cars...')
      adapter.execute('select * from cars')
      adapter.execute('select * from cars')
    end
  end

  context 'with dry slaves' do

    let(:config){ multi_slave_config.merge(:sticky_slave => false) }


    it 'should rotate through slaves until master is used' do
      adapter.scon(2).should_receive(:execute).with('select * from dogs', nil).once
      adapter.scon(1).should_receive(:execute).with('select * from cats', nil).once
      adapter.mcon.should_receive(:execute).with('insert into animals...', nil).once
      adapter.mcon.should_receive(:execute).with('select * from pumas', nil).once
      adapter.mcon.should_receive(:execute).with('select * from panthers', nil).once

      adapter.execute('select * from dogs')
      adapter.execute('select * from cats')
      adapter.execute('insert into animals...')
      adapter.execute('select * from pumas')
      adapter.execute('select * from panthers')
    end

  end

  context 'with a completely dry configuration' do

    let(:config){ dry_multi_slave_config }

    it 'should pass control around to all underlying adapters' do
      adapter.scon(2).should_receive(:execute).with('select * from dogs', nil).once
      adapter.scon(1).should_receive(:execute).with('select * from cats', nil).once
      adapter.mcon.should_receive(:execute).with('insert into animals...', nil).once
      adapter.scon(2).should_receive(:execute).with('select * from pumas', nil).once  
      adapter.scon(1).should_receive(:execute).with('select * from panthers', nil).once

      adapter.execute('select * from dogs')
      adapter.execute('select * from cats')
      adapter.execute('insert into animals...')
      adapter.execute('select * from pumas')
      adapter.execute('select * from panthers')

    end
  end

  def stub_all_connections!
    adapter.send(:all_connections).each do |con|
      con.stub(:execute).and_return(true)
    end
  end

end