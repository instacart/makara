require 'uri'
require 'active_record'
require 'makara'
require 'timecop'
require 'yaml'
require 'rack'

begin
  require 'byebug'
rescue LoadError
end

begin
  require 'ruby-debug'
rescue LoadError
end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.order = 'random'

  require "#{File.dirname(__FILE__)}/support/helpers"
  require "#{File.dirname(__FILE__)}/support/proxy_extensions"
  require "#{File.dirname(__FILE__)}/support/pool_extensions"
  require "#{File.dirname(__FILE__)}/support/mock_objects"
  require "#{File.dirname(__FILE__)}/support/deep_dup"
  require "#{File.dirname(__FILE__)}/support/user"

  config.include SpecHelpers

  config.before :each do
    change_context
    allow_any_instance_of(Makara::Strategies::RoundRobin).to receive(:should_shuffle?){ false }
    RSpec::Mocks.space.proxy_for(ActiveRecord::Base).reset # make sure not stubbed in some way
  end

  def change_context
    Makara::Context.set_current({})
  end
end

class SpecQuerySequenceTracker
  def initialize(parent_connection, example)
    @connection = parent_connection
    @example = example
    @query_seq = {}
    @query_seq.compare_by_identity
    all_connections = @connection.master_pool.connections + @connection.slave_pool.connections
    all_connections.each do |con|
      @example.allow(con._makara_connection).to @example.receive(:execute).and_wrap_original do |_, *args|
        @query_seq[con] ||= []
        @query_seq[con] << args[0]
      end
    end
  end

  def expect_primary_seq(*expected_seq)
    expected_seq = nil if expected_seq.count == 1 && expected_seq.first.nil?
    primary_con_seq = @query_seq[@connection.master_pool.connections.first]
    @example.expect(primary_con_seq).to @example.eq(expected_seq)
  end

  def expect_replica_seq(*expected_seq)
    expected_seq = nil if expected_seq.count == 1 && expected_seq.first.nil?
    replica_con_seq = @query_seq[@connection.slave_pool.connections.first]
    @example.expect(replica_con_seq).to @example.eq(expected_seq)
  end
end
