require 'spec_helper'

describe 'MakaraPostgreSQLAdapter' do

  let(:db_username){ ENV['TRAVIS'] ? 'postgres' : `whoami`.chomp }

  let(:config){
    base = YAML.load_file(File.expand_path('spec/support/postgresql_database.yml'))['test']
    base['username'] = db_username
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


  it 'should allow a connection to be established' do
    ActiveRecord::Base.establish_connection(config)
    expect(ActiveRecord::Base.connection).to be_instance_of(ActiveRecord::ConnectionAdapters::MakaraPostgreSQLAdapter)
  end

  it 'should not blow up if a connection fails' do
    config['makara']['connections'].select{|h| h['role'] == 'slave' }.each{|h| h['username'] = 'other'}

    require 'active_record/connection_adapters/postgresql_adapter'

    original_method = ActiveRecord::Base.method(:postgresql_connection)

    allow(ActiveRecord::Base).to receive(:postgresql_connection) do |config|
      if config[:username] == 'other'
        raise "could not connect"
      else
        original_method.call(config)
      end
    end

    ActiveRecord::Base.establish_connection(config)
    ActiveRecord::Base.connection

    allow(ActiveRecord::Base).to receive(:postgresql_connection) do |config|
      config[:username] = db_username
      original_method.call(config)
    end

    ActiveRecord::Base.connection.slave_pool.connections.each(&:_makara_whitelist!)
    ActiveRecord::Base.connection.slave_pool.connections.each(&:adapter_name)
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
      connection.execute('INSERT INTO users (name) VALUES (\'John\')')

      connection.master_pool.connections.each do |master|
        expect(master).to receive(:execute).never
      end

      Makara::Context.set_current Makara::Context.generate
      res = connection.execute('SELECT name FROM users ORDER BY id DESC LIMIT 1')

      expect(res.to_a[0]['name']).to eq('John')
    end

    it 'should send SET operations to each connection' do
      connection.master_pool.connections.each do |con|
        expect(con).to receive(:execute).with("SET TimeZone = 'UTC'").once
      end

      connection.slave_pool.connections.each do |con|
        expect(con).to receive(:execute).with("SET TimeZone = 'UTC'").once
      end
      connection.execute("SET TimeZone = 'UTC'")
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
