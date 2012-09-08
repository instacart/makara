require 'active_record/connection_adapters/mysql_adapter'

module ActiveRecord
  
  class Base
    def self.makara_connection(config)

      adapter_method = "#{config[:db_adapter]}_connection"

      unless self.respond_to?(adapter_method)
        begin
          require 'rubygems'
          gem "activerecord-#{config[:db_adapter]}-adapter"
        rescue LoadError
        end

        begin
          require "active_record/connection_adapters/#{config[:db_adapter]}_adapter"
        rescue LoadError
          raise "Please install the #{config[:db_adapter]} adapter: `gem install activerecord-#{config[:db_adapter]}-adapter` (#{$!})"
        end
      end


      master_connection = self.send(adapter_method, config)
      slave_connections = ::Makara::ConnectionBuilder::each_slave_config(config) do |slave_config|
        self.send(adapter_method, slave_config)
      end

      ::ActiveRecord::ConnectionAdapters::MakaraAdapter.new(master_connection, slave_connections)
    end

  end

  module ConnectionAdapters

    class MakaraAdapter

      SQL_KEYWORDS = ['insert', 'update', 'delete', 'show tables', 'alter']
      SQL_EXPRESSION = /#{SQL_KEYWORDS.join('|')}/

      def initialize(master_connection, slave_connections)

        master_config = master_connection.instance_variable_get('@config')

        # sticky master by default
        @sticky_master = true
        @sticky_master = !!master_config.delete(:sticky_master) if master_config.has_key?(:sticky_master)

        # sticky slaves by default
        @sticky_slaves = true
        @sticky_slaves = !!master_config.delete(:sticky_slaves) if master_config.has_key?(:sticky_slaves)

        @master  = ::Makara::ConnectionWrapper::MasterWrapper.new(master_connection, 'master')
        @slaves  = ::Makara::ConnectionBuilder::build_slave_linked_list(slave_connections)

        decorate_connections!

        reset_current_slave
      end

      # the execute method which routes it's call to the correct underlying adapter.
      # if we're already stuck on a connection, continue using it. if we want to be stuck on a connection, stick to it.
      # 
      def execute(sql, name = nil)
        
        # the connection wrapper that should handle the execute call
        wrapper = current_wrapper_for(sql)

        # stick to it if we determine that's the right thing to do
        stick!(wrapper) if should_stick?(wrapper)

        # mark ourselves as being in a hijack block so we don't invoke this execute() unecessarily
        hijacking_execute! do
          logger.info "Using: #{wrapper.name}"
          # hand off control to the wrapper
          wrapper.execute(sql, name)
        end

      # catch all exceptions for now, since we don't know what adapter we'll be using or how they'll be formatted
      rescue Exception => e

        # we caught this exception while invoking something on the master connection, raise the error
        raise e if wrapper.nil? || wrapper.master?

        # something has gone wrong, we need to release this sticky connection
        unstick!

        # let's blacklist this slave to ensure it's removed from the slave cycle
        wrapper.blacklist!
        
        # do it!
        retry
      end

      def method_missing(method_name, *args)
        @master.connection.send(method_name, *args)
      end

      def respond_to?(method_name, include_private = false)
        super || @master.connection.respond_to?(method_name, include_private)
      end

      # if we want to unstick the current connection (request is over, testing, etc)
      def unstick!
        @stuck_on = nil
      end
      alias_method :release!, :unstick!

      # the game
      def stuck_on
        @stuck_on
      end

      # should we be sticking to slaves once they're invoked?
      def sticky_slave?
        !!@sticky_slaves
      end
      alias_method :sticky_slaves?, :sticky_slave?

      # should we stick with the master once it's invoked?
      def sticky_master?
        !!@sticky_master
      end

      # are we currently hijacking an execute call and choosing the appropriate connection?
      def hijacking_execute?
        !!@hijacking_execute
      end

      def force_master!
        @master_forced = true
      end


      protected


      # the connection wrapper which should be chosen based on the sql we've provided.
      # if we're dealing with a sql statement which requires master access, use it.
      # otherwise, let's use the currently stuck connection, the next available slave, or the master connection
      def current_wrapper_for(sql)
        return @master if requires_master?(sql)
        @stuck_on || next_slave || @master
      end

      # denote that we're hijacking an execute call
      def hijacking_execute!
        @hijacking_execute = true
        yield
      ensure
        @hijacking_execute = false
      end

      # we need a concept of the current slave for iteration purposes. this resets that current to the first slave
      def reset_current_slave
        @current_slave = @slaves.first
      end

      # get the next available slave. if none are available this will return nil
      def next_slave
        @current_slave = @current_slave.try(:next)
      end

      # let's get stuck on a wrapper so we continue utilizing the same connection for the duration of this request (or until we're unstuck)
      def stick!(wrapper)
        @stuck_on = wrapper
      end

      # are we currently stuck on a wrapper?
      def currently_stuck?
        !!@stuck_on
      end

      # given the wrapper and the current configuration, should we stick to this guy?
      # note: if all wrappers are sticky, we should stick to the master even if we've already stuck
      # to a slave.
      def should_stick?(wrapper)
        return true if sticky_master? && wrapper.master?
        return true if sticky_slave? && wrapper.slave?
        false
      end

      # based on this sql command, should we require the master connection be used?
      # override this if you'd like to globally set to master in a block
      def requires_master?(sql)
        return true if @master_forced
        !!(sql.to_s.downcase =~ SQL_EXPRESSION)
      end


      # we need a concept of the current slave for iteration purposes. this resets that current to the first slave
      def reset_current_slave
        @current_slave = next_slave || @slaves.first
      end


      # decorate our database adapters to invoke our execute before they invoke their own
      def decorate_connections!
        decorate_connection(@master.connection)
        @slaves.each{|s| decorate_connection(s.connection) }
      end

      def decorate_connection(con)
        con.extend ::Makara::ConnectionWrapper::ConnectionDecorator
        con.makara_adapter = self
        con
      end

      def logger
        ActiveRecord::Base.logger
      end

    end
  end
end