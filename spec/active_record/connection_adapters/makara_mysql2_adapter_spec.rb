require 'spec_helper'
require 'active_record/connection_adapters/mysql2_adapter'

describe 'MakaraMysql2Adapter' do

  let(:db_username){ ENV['TRAVIS'] ? 'travis' : 'root' }

  let(:config){
    base = YAML.load_file(File.expand_path('spec/support/mysql2_database.yml'))['test']
    base
  }

  before do
    if ActiveRecord::Base.connected?
      ActiveRecord::Base.connection.tap do |c|
        c.master_pool.connections.each(&:_makara_whitelist!)
        c.slave_pool.connections.each(&:_makara_whitelist!)
      end
    end
    Makara::Context.set_current Makara::Context.generate
  end

  context "unconnected" do

    it 'should allow a connection to be established' do
      ActiveRecord::Base.establish_connection(config)
      expect(ActiveRecord::Base.connection).to be_instance_of(ActiveRecord::ConnectionAdapters::MakaraMysql2Adapter)
    end

    it 'should not blow up if a connection fails' do
      config['makara']['connections'].select{|h| h['role'] == 'slave' }.each{|h| h['username'] = 'other'}

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

      load(File.dirname(__FILE__) + '/../../support/schema.rb')
      Makara::Context.set_current Makara::Context.generate

      allow(ActiveRecord::Base).to receive(:mysql2_connection) do |config|
        config[:username] = db_username
        original_method.call(config)
      end

      ActiveRecord::Base.connection.slave_pool.connections.each(&:_makara_whitelist!)
      ActiveRecord::Base.connection.slave_pool.provide do |con|
        res = con.execute('SELECT count(*) FROM users')
        if defined?(JRUBY_VERSION)
          expect(res[0]).to eq('count(*)' => 0)
        else
          expect(res.to_a[0][0]).to eq(0)
        end
      end
    end

    it 'should execute a send_to_all against master even if no slaves are connected' do
      ActiveRecord::Base.establish_connection(config)
      connection = ActiveRecord::Base.connection

      connection.slave_pool.connections.each do |c|
        allow(c).to receive(:_makara_blacklisted?){ true }
        allow(c).to receive(:_makara_connected?){ false }
        expect(c).to receive(:execute).with('SET @t1 = 1').never
      end

      connection.master_pool.connections.each do |c|
        expect(c).to receive(:execute).with('SET @t1 = 1')
      end

      expect{
        connection.execute('SET @t1 = 1')
      }.not_to raise_error
    end

    it 'should execute a send_to_all and raise a NoConnectionsAvailable error' do
      ActiveRecord::Base.establish_connection(config)
      connection = ActiveRecord::Base.connection

      (connection.slave_pool.connections | connection.master_pool.connections).each do |c|
        allow(c).to receive(:_makara_blacklisted?){ true }
        allow(c).to receive(:_makara_connected?){ false }
        expect(c).to receive(:execute).with('SET @t1 = 1').never
      end

      expect{
        connection.execute('SET @t1 = 1')
      }.to raise_error(Makara::Errors::NoConnectionsAvailable)

    end

  end

  context 'with the connection established and schema loaded' do

    let(:connection) { ActiveRecord::Base.connection }

    before do
      ActiveRecord::Base.establish_connection(config)
      load(File.dirname(__FILE__) + '/../../support/schema.rb')
      Makara::Context.set_current Makara::Context.generate
    end


    it 'should have one master and two slaves' do
      expect(connection.master_pool.connection_count).to eq(1)
      expect(connection.slave_pool.connection_count).to eq(2)
    end

    it 'should allow real queries to work' do
      connection.execute("INSERT INTO users (name) VALUES ('John')")

      connection.master_pool.connections.each do |master|
        expect(master).to receive(:execute).never
      end

      Makara::Context.set_current Makara::Context.generate

      res = connection.execute('SELECT name FROM users ORDER BY id DESC LIMIT 1')

      if defined?(JRUBY_VERSION)
        expect(res[0]['name']).to eq('John')
      else
        expect(res.to_a[0][0]).to eq('John')
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
      # ensure the next connection will be the first one
      connection.slave_pool.instance_variable_set('@current_idx', connection.slave_pool.connections.length)

      con = connection.slave_pool.connections.first
      expect(con).to receive(:execute).with('SELECT * FROM users').once

      connection.execute('SELECT * FROM users')
    end

    it 'should send writes to master' do
      con = connection.master_pool.connections.first
      expect(con).to receive(:execute).with('UPDATE users SET name = "bob" WHERE id = 1')
      connection.execute('UPDATE users SET name = "bob" WHERE id = 1')
    end

  end

end
