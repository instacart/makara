require 'spec_helper'

describe 'MakaraMysql2Adapter' do

  let(:config){
    base = YAML.load_file(File.expand_path('spec/support/mysql2_database.yml'))['test']
    base['username'] = 'travis' if ENV['TRAVIS']
    base
  }

  it 'should allow a connection to be established' do
    ActiveRecord::Base.establish_connection(config)
    expect(ActiveRecord::Base.connection).to be_instance_of(ActiveRecord::ConnectionAdapters::MakaraMysql2Adapter)
  end

  it 'should not blow up if a connection fails' do
    config['makara']['connections'].select{|h| h['role'] == 'slave' }.each{|h| h['username'] = 'other'}

    require 'active_record/connection_adapters/mysql2_adapter'

    original_method = ActiveRecord::Base.method(:mysql2_connection)

    allow(ActiveRecord::Base).to receive(:mysql2_connection) do |config|
      if config[:username] == 'other'
        raise "could not connect"
      else
        original_method.call(config)
      end
    end

    ActiveRecord::Base.establish_connection(config)
    ActiveRecord::Base.connection
  end

  context 'with the connection established' do

    before do
      ActiveRecord::Base.establish_connection(config)
    end

    let(:connection) { ActiveRecord::Base.connection }

    it 'should have one master and two slaves' do
      expect(connection.master_pool.connection_count).to eq(1)
      expect(connection.slave_pool.connection_count).to eq(2)
    end

    it 'should allow real queries to work' do
      connection.execute('SET @t1 = "blah"')

      connection.master_pool.connections.each do |master|
        expect(master).to receive(:execute).never
      end

      res = connection.execute('SELECT @t1')

      if defined?(JRUBY_VERSION)
        expect(res[0]['@t1']).to eq('blah')
      else
        expect(res.to_a[0][0]).to eq('blah')
      end
    end

    it 'should send SET operations to each connection' do
      connection.master_pool.connections.each do |con|
        expect(con).to receive(:execute).with('SET @t1 = 1').once
      end

      connection.slave_pool.connections.each do |con|
        expect(con).to receive(:execute).with('SET @t1 = 1').once
      end
      connection.execute("SET @t1 = 1")
    end

    it 'should send reads to the slave' do
      con = connection.slave_pool.connections.first
      expect(con).to receive(:execute).with('SELECT @t1').once

      connection.execute('SELECT @t1')
    end

    it 'should send writes to master' do
      con = connection.master_pool.connections.first
      expect(con).to receive(:execute).with('UPDATE users SET name = "bob" WHERE id = 1')
      connection.execute('UPDATE users SET name = "bob" WHERE id = 1')
    end

  end

end
