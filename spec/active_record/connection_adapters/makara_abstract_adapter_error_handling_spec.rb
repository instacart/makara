require 'spec_helper'
require 'active_record/connection_adapters/makara_abstract_adapter'

describe ActiveRecord::ConnectionAdapters::MakaraAbstractAdapter::ErrorHandler do

  let(:handler){ described_class.new }
  let(:proxy) { FakeAdapter.new(config(1,1)) }
  let(:connection){ proxy.master_pool.connections.first }

  [
    %|Mysql::Error: : INSERT INTO `watchers` (`user_id`, `watchable_id`, `watchable_type`) VALUES|,
    %|PGError: ERROR: column items.user_id does not exist LINE 1: SELECT "items".* FROM "items" WHERE ("items".user_id = 4) OR|
  ].each do |msg|
    it "should properly evaluate errors like: #{msg}" do
      expect(handler).not_to be_connection_message(msg)
    end

    it 'should raise the error' do
      expect{
        handler.handle(connection) do
          raise msg
        end
      }.to raise_error(msg)
    end
  end

  [
    %|Mysql2::Error: closed MySQL connection: SELECT `users`.* FROM `users`|,
    %|Mysql2::Error: MySQL server has gone away: SELECT `users`.* FROM `users`|,
    %|Mysql2::Error: Lost connection to MySQL server during query: SELECT `geographies`.* FROM `geographies`|,
    %|PGError: server closed the connection unexpectedly This probably me|,
    %|Could not connect to server: Connection refused Is the server running on host|,
    %|PG::AdminShutdown: FATAL:  terminating connection due to administrator command FATAL:  terminating connection due to administrator command|,
    %|PG::ConnectionBad: PQconsumeInput() SSL connection has been closed unexpectedly: SELECT  1 AS one FROM "users"  WHERE "users"."registration_ip" = '10.0.2.2' LIMIT 1|,
    %|PG::UnableToSend: no connection to the server|
  ].each do |msg|
    it "should properly evaluate connection messages like: #{msg}" do
      expect(handler).to be_connection_message(msg)
    end

    it 'should blacklist the connection' do
      expect {
        handler.handle(connection) do
          raise msg
        end
      }.to raise_error(Makara::Errors::BlacklistConnection)
    end
  end


end
