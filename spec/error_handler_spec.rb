require 'spec_helper'

describe Makara::Connection::ErrorHandler do

  before do
    connect!(config)
  end

  let(:config){ single_slave_config }
  let(:handler){ adapter.instance_variable_get('@exception_handler') }

  [
    %|Mysql::Error: : INSERT INTO `watchers` (`user_id`, `watchable_id`, `watchable_type`) VALUES|,
    %|PGError: ERROR: column items.user_id does not exist LINE 1: SELECT "items".* FROM "items" WHERE ("items".user_id = 4) OR|
  ].each do |msg|
    it "should properly evaluate actual errors like: #{msg}" do
      handler.should_not be_connection_message(msg)
    end
  end

  [
    %|Mysql2::Error: closed MySQL connection: SELECT `users`.* FROM `users`|,
    %|Mysql2::Error: MySQL server has gone away: SELECT `users`.* FROM `users`|,
    %|Mysql2::Error: Lost connection to MySQL server during query: SELECT `geographies`.* FROM `geographies`|,
    %|PGError: server closed the connection unexpectedly This probably me|
  ].each do |msg|
    it "should properly evalute connection messages like: #{msg}" do
      handler.should be_connection_message(msg)
    end
  end

  it 'should handle the error harshly if no current wrapper is present' do
    error = exception('any error')
    handler.should_receive(:handle_exception_harshly).with(error)
    adapter.stub(:current_wrapper).and_return(nil)
    handler.handle(error)
  end

  it 'should handle the error harshly if the current wrapper is a master' do
    error = exception('any error')
    handler.should_receive(:handle_exception_harshly).with(error)
    adapter.stub(:current_wrapper).and_return(adapter.master)
    handler.handle(error)
  end

  it 'should gracefully handle connection errors and blacklist the slave' do
    error = exception('lost connection')
    slave = adapter.slave

    handler.should_receive(:handle_exception_harshly).never
    handler.stub(:current_wrapper).and_return(slave)
    slave.should_receive(:blacklist!).once

    handler.handle(error)
  end

  Makara::Connection::ErrorHandler::HARSH_ERRORS.map(&:constantize).each do |klazz|
    it "should handle #{klazz} harshly" do
      error = klazz.new('some kind of statement error', exception('some kind of statement error'))
      handler.should_receive(:handle_exception_harshly).once
      handler.handle(error)
    end
  end


  def exception(msg)
    ActiveRecord::StatementInvalid.new(msg)
  end
end