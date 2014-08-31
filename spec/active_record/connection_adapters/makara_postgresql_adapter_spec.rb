require 'spec_helper'
require 'active_record/connection_adapters/postgresql_adapter'

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
    change_context
  end


  it 'should allow a connection to be established' do
    ActiveRecord::Base.establish_connection(config)
    expect(ActiveRecord::Base.connection).to be_instance_of(ActiveRecord::ConnectionAdapters::MakaraPostgreSQLAdapter)
  end

  context 'with the connection established and schema loaded' do

    let(:connection) { ActiveRecord::Base.connection }

    before do
      ActiveRecord::Base.establish_connection(config)
      load(File.dirname(__FILE__) + '/../../support/schema.rb')
      change_context
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

      change_context
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
