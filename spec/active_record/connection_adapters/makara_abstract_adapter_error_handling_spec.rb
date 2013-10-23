require 'spec_helper'
require 'active_record/connection_adapters/makara_abstract_adapter'

describe ActiveRecord::ConnectionAdapters::MakaraAbstractAdapter::ErrorHandler do

  let(:handler){ described_class.new }

  [
    %|Mysql::Error: : INSERT INTO `watchers` (`user_id`, `watchable_id`, `watchable_type`) VALUES|,
    %|PGError: ERROR: column items.user_id does not exist LINE 1: SELECT "items".* FROM "items" WHERE ("items".user_id = 4) OR|
  ].each do |msg|
    it "should properly evaluate errors like: #{msg}" do
      expect(handler).not_to be_connection_message(msg)
    end
  end

  [
    %|Mysql2::Error: closed MySQL connection: SELECT `users`.* FROM `users`|,
    %|Mysql2::Error: MySQL server has gone away: SELECT `users`.* FROM `users`|,
    %|Mysql2::Error: Lost connection to MySQL server during query: SELECT `geographies`.* FROM `geographies`|,
    %|PGError: server closed the connection unexpectedly This probably me|
  ].each do |msg|
    it "should properly evalute connection messages like: #{msg}" do
      expect(handler).to be_connection_message(msg)
    end
  end

end
