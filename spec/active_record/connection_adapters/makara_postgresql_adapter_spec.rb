require 'spec_helper'
require 'active_record/connection_adapters/postgresql_adapter'
require 'active_record/errors'

describe 'MakaraPostgreSQLAdapter' do
  let(:config) do
    YAML.load_file(File.expand_path('spec/support/postgresql_database.yml'))['test']
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

    it 'should have one primary and two replicas' do
      expect(connection.primary_pool.connection_count).to eq(1)
      expect(connection.replica_pool.connection_count).to eq(2)
    end

    it 'should allow real queries to work' do
      connection.execute('INSERT INTO users (name) VALUES (\'John\')')

      connection.primary_pool.connections.each do |primary|
        expect(primary).to receive(:execute).never
      end

      change_context
      res = connection.execute('SELECT name FROM users ORDER BY id DESC LIMIT 1')

      expect(res.to_a[0]['name']).to eq('John')
    end

    it 'should send SET operations to each connection' do
      connection.primary_pool.connections.each do |con|
        expect(con).to receive(:execute).with("SET TimeZone = 'UTC'").once
      end

      connection.replica_pool.connections.each do |con|
        expect(con).to receive(:execute).with("SET TimeZone = 'UTC'").once
      end
      connection.execute("SET TimeZone = 'UTC'")
    end

    it 'should send reads to the replica' do
      # ensure the next connection will be the first one
      allow_any_instance_of(Makara::Strategies::RoundRobin).to receive(:single_one?){ true }

      con = connection.replica_pool.connections.first
      expect(con).to receive(:execute).with('SELECT * FROM users').once

      connection.execute('SELECT * FROM users')
    end

    it 'should send exists? to replica' do
      allow_any_instance_of(Makara::Strategies::RoundRobin).to receive(:single_one?){ true }
      Test::User.exists? # flush other (schema) things that need to happen

      con = connection.replica_pool.connections.first

      expect(con).to receive(:exec_query) do |query|
        expect(query).to match(/SELECT\s+1\s*(AS one)?\s+FROM .?users.?\s+LIMIT\s+.?1/)
      end.once.
        # and_call_original # Switch back to this once https://github.com/rspec/rspec-mocks/pull/1385 is released
        and_wrap_original { |m, *args| m.call(*args.first(3)) }

      Test::User.exists?
    end

    it 'should send writes to primary' do
      con = connection.primary_pool.connections.first
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

  context 'with only primary connection' do
    it 'should not raise errors on read and write' do
      custom_config = config.deep_dup
      custom_config['makara']['connections'].select{|h| h['role'] == 'replica' }.each{|h| h['port'] = '1'}

      establish_connection(custom_config)
      load(File.dirname(__FILE__) + '/../../support/schema.rb')

      connection.execute('SELECT * FROM users')
      connection.execute('INSERT INTO users (name) VALUES (\'John\')')
    end
  end

  context 'with only replica connection' do
    it 'should raise error only on write' do
      establish_connection(config)
      load(File.dirname(__FILE__) + '/../../support/schema.rb')
      ActiveRecord::Base.clear_all_connections!

      custom_config = config.deep_dup
      custom_config['makara']['connections'].select{|h| h['role'] == 'primary' }.each{|h| h['port'] = '1'}

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

        # Pre-loads the attributes so that schema queries don't hit replica
        # user = User.create(name: 'hello')
        connection.replica_pool.connections.each do |replica|
          # Using method missing to help with back trace, literally
          # no query should be executed on replica once a transaction is opened
          expect(replica).to receive(:method_missing).never
          expect(replica).to receive(:execute).never
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

  context 'with two activerecord connection pools' do
    before :each do
      class Model1 < ActiveRecord::Base
      end

      class Model2 < ActiveRecord::Base
      end

      Model1.establish_connection(config)
      Model2.establish_connection(config)
    end

    it 'should not leak raw connection into activerecord pool' do
      # checkout a connection from Model1 pool and remove from the pool
      conn = Model1.connection_pool.checkout
      Model1.connection_pool.remove(conn)

      # assign the connection to Model2 pool
      conn.pool=Model2.connection_pool

      # now close the connection to return it back to the pool
      conn.close

      # checkout the connection and make sure it is still a makara proxy
      expect(Model2.connection).to eq(conn)
    end

    it 'should be able to steal the connection from a different thread' do
      conn = Model1.connection_pool.checkout
      conn.steal!
      expect(conn.owner).to eq(Thread.current)
      # steal! is not thread safe. it should be done while holding connection pool's mutex
      t = Thread.new { conn.steal! }
      t.join
      expect(conn.owner).to eq(t)
    end

    it 'should not be able to expire the connection from same thread' do
      conn = Model2.connection_pool.checkout
      # expire is not thread safe. it should be done while holding connection pool's mutex
      expect {
        t = Thread.new { conn.expire }
        t.join
      }.to raise_error(ActiveRecord::ActiveRecordError)
    end

    it 'should be able to checkin connection back into activerecord pool' do
      conn = Model1.connection_pool.checkout
      Model1.connection_pool.checkin(conn)
      # checkout the connection again and make sure it is same connection
      expect(Model1.connection).to eq(conn)
    end
  end
end
