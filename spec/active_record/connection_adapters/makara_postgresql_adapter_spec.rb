require 'spec_helper'
require 'active_record/connection_adapters/postgresql_adapter'

describe 'MakaraPostgreSQLAdapter' do

  let(:db_username){ ENV['TRAVIS'] ? 'postgres' : `whoami`.chomp }

  let(:config) do
    base = YAML.load_file(File.expand_path('spec/support/postgresql_database.yml'))['test']
    base['username'] = db_username
    base
  end

  let(:connection) { ActiveRecord::Base.connection }

  before :each do
    ActiveRecord::Base.clear_all_connections!
    change_context
  end


  it 'should allow a connection to be established' do
    establish_connection(config)
    expect(ActiveRecord::Base.connection).to be_instance_of(ActiveRecord::ConnectionAdapters::MakaraPostgreSQLAdapter)
  end

  context 'with the connection established and schema loaded' do

    before do
      establish_connection(config)
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
      connection.slave_pool.strategy.instance_variable_set('@current_idx', connection.slave_pool.connections.length)

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

  context 'without live connections' do
    it 'should raise errors on read or write' do
      allow(ActiveRecord::Base).to receive(:postgresql_connection).and_raise(StandardError.new('could not connect to server: Connection refused'))

      ActiveRecord::Base.establish_connection(config)
      expect { connection.execute('SELECT * FROM users') }.to raise_error(Makara::Errors::NoConnectionsAvailable)
      expect { connection.execute('INSERT INTO users (name) VALUES (\'John\')') }.to raise_error(Makara::Errors::NoConnectionsAvailable)
    end
  end

  context 'with only master connection' do
    it 'should not raise errors on read and write' do
      custom_config = config.deep_dup
      custom_config['makara']['connections'].select{|h| h['role'] == 'slave' }.each{|h| h['port'] = '1'}

      establish_connection(custom_config)
      load(File.dirname(__FILE__) + '/../../support/schema.rb')

      connection.execute('SELECT * FROM users')
      connection.execute('INSERT INTO users (name) VALUES (\'John\')')
    end
  end

  context 'with only slave connection' do
    it 'should raise error only on write' do
      establish_connection(config)
      load(File.dirname(__FILE__) + '/../../support/schema.rb')
      ActiveRecord::Base.clear_all_connections!

      custom_config = config.deep_dup
      custom_config['makara']['connections'].select{|h| h['role'] == 'master' }.each{|h| h['port'] = '1'}

      establish_connection(custom_config)

      connection.execute('SELECT * FROM users')
      expect { connection.execute('INSERT INTO users (name) VALUES (\'John\')') }.to raise_error(Makara::Errors::NoConnectionsAvailable)
    end
  end

  describe 'transaction support' do
    shared_examples 'a transaction supporter' do
      before do
        establish_connection(config)
        load(File.dirname(__FILE__) + '/../../support/schema.rb')
        change_context

        # Pre-loads the attributes so that schema queries don't hit slave
        # user = User.create(name: 'hello')
        connection.slave_pool.connections.each do |slave|
          # Using method missing to help with back trace, literally
          # no query should be executed on slave once a transaction is opened
          expect(slave).to receive(:method_missing).never
          expect(slave).to receive(:execute).never
        end
      end

      context 'when querying through a polymorphic relation' do
        it 'should respect the transaction' do
          ActiveRecord::Base.transaction do
            connection.execute("INSERT INTO users (name) VALUES ('John')")
            connection.execute('SELECT * FROM users')
          end
        end
      end

      context 'when querying an aggregate' do
        it 'should respect the transaction' do
          ActiveRecord::Base.transaction { connection.execute('SELECT COUNT(*) FROM users') }
        end
      end

      context 'when querying for a specific record' do
        it 'should respect the transaction' do
          ActiveRecord::Base.transaction { connection.execute('SELECT * FROM users WHERE id = 1') }
        end
      end

      context 'when executing a query' do
        it 'should respect the transaction' do
          ActiveRecord::Base.transaction { connection.execute('SELECT 1') }
        end
      end
    end

    context 'when sticky is true' do
      before { config['makara']['sticky'] = true }

      it_behaves_like 'a transaction supporter'
    end

    context 'when sticky is false' do
      before { config['makara']['sticky'] = false }

      it_behaves_like 'a transaction supporter'
    end
  end
end
