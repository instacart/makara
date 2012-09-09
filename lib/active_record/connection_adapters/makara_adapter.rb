module ActiveRecord
  
  class Base

    def self.makara_connection(config)
      master_config     = ::Makara::ConnectionBuilder::master_config(config)
      master_connection = underlying_connection_for(master_config)

      slave_connections = ::Makara::ConnectionBuilder::each_slave_config(config) do |slave_config|
        underlying_connection_for(slave_config)
      end

      ::ActiveRecord::ConnectionAdapters::MakaraAdapter.new(master_connection, slave_connections, config)
    end

    protected

    def self.underlying_connection_for(config)
      adapter_name = config[:db_adapter] || config[:adapter]

      adapter_method = "#{adapter_name}_connection"

      unless self.respond_to?(adapter_method)
        begin
          require "active_record/connection_adapters/#{adapter_name}_adapter"
        rescue LoadError
          raise "Please install the #{adapter_name} adapter: `gem install activerecord-#{adapter_name}-adapter` (#{$!})"
        end
      end

      self.send(adapter_method, config)
    end

  end

  module ConnectionAdapters

    class MakaraAdapter

      SQL_SLAVE_KEYWORDS = ['select', 'show tables', 'show fields', 'describe']
      SQL_SLAVE_MATCHER = /#{SQL_SLAVE_KEYWORDS.join('|')}/

      MASS_DELEGATION_METHODS = %w(active? reconnect! disconnect! reset! verify!)

      def initialize(master_connection, slave_connections, options = {})

        # sticky master by default
        @sticky_master  = true
        @sticky_master  = !!options.delete(:sticky_master) if options.has_key?(:sticky_master)

        # sticky slaves by default
        @sticky_slaves  = true
        @sticky_slaves  = !!options.delete(:sticky_slaves) if options.has_key?(:sticky_slaves)

        @verbose        = options.delete(:verbose)
        
        @master         = ::Makara::ConnectionWrapper::MasterWrapper.new(master_connection, 'master')
        @slaves         = ::Makara::ConnectionBuilder::build_slave_linked_list(slave_connections)

        decorate_connections!

        reset_current_slave
      end

      MASS_DELEGATION_METHODS.each do |aggregate_method|

        class_eval <<-AGG_METHOD, __FILE__, __LINE__ + 1
          def #{aggregate_method}(*args)
            send_to_all!(:#{aggregate_method}, *args)
          end
        AGG_METHOD

      end


      # the execute method which routes it's call to the correct underlying adapter.
      # if we're already stuck on a connection, continue using it. if we want to be stuck on a connection, stick to it.
      # 
      def execute(sql, name = nil)
        
        # the connection wrapper that should handle the execute call
        @current_wrapper = current_wrapper_for(sql)

        # stick to it if we determine that's the right thing to do
        stick! if should_stick?

        # mark ourselves as being in a hijack block so we don't invoke this execute() unecessarily
        hijacking_execute! do
          # hand off control to the wrapper
          @current_wrapper.execute(sql, name)
        end

      # catch all exceptions for now, since we don't know what adapter we'll be using or how they'll be formatted
      rescue Exception => e

        # we caught this exception while invoking something on the master connection, raise the error
        if @current_wrapper.nil? || @current_wrapper.master?
          error("Error caught in makara adapter while using #{@current_wrapper}:")
          raise e 
        end
        # something has gone wrong, we need to release this sticky connection
        unstick!

        # let's blacklist this slave to ensure it's removed from the slave cycle
        @current_wrapper.blacklist!
        warn("Blacklisted [#{@current_wrapper.name}]")
        
        # do it!
        retry
      end


      # 
      def with_master
        old_value = @master_forced
        force_master!        
        yield
      ensure
        @master_forced = old_value
        info("Releasing forced master")
      end


      def method_missing(method_name, *args, &block)
        @master.connection.send(method_name, *args, &block)
      end

      def respond_to?(method_name, include_private = false)
        super || @master.connection.respond_to?(method_name, include_private)
      end

      # provide an easy way to get the name of the current wrapper
      # especially useful for logging
      def current_wrapper_name
        @current_wrapper.try(:name)
      end

      # if we want to unstick the current connection (request is over, testing, etc)
      def unstick!
        @stuck_on = nil
      end

      # are we currently hijacking an execute call and choosing the appropriate connection?
      def hijacking_execute?
        !!@hijacking_execute
      end

      def force_master!
        @master_forced = true
        info("Forcing master")
      end


      def inspect
        "#<#{self.class.name} current: #{@current_wrapper.try(:name)}, sticky: [#{[@sticky_master ? 'master' : nil, @sticky_slaves ? 'slaves' : nil].compact.join(', ')}], verbose: #{@verbose}, master: 1, slaves: #{@slaves.length} >"
      end


      protected

      def send_to_all!(method_name, *args)
        all_connections.each do |con|
          con.send(method_name, *args)
        end
      end

      def all_wrappers
        [@master, @slaves].flatten.compact
      end

      def all_connections
        all_wrappers.map(&:connection)
      end


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

      # get the next available slave. if none are available this will return nil
      def next_slave
        @current_slave = @current_slave.try(:next)
      end

      # let's get stuck on a wrapper so we continue utilizing the same connection for the duration of this request (or until we're unstuck)
      def stick!
        info("Sticking to: #{@current_wrapper}")
        @stuck_on = @current_wrapper
      end

      # are we currently stuck on a wrapper?
      def currently_stuck?
        !!@stuck_on
      end

      # given the wrapper and the current configuration, should we stick to this guy?
      # note: if all wrappers are sticky, we should stick to the master even if we've already stuck
      # to a slave.
      def should_stick?
        
        return false if currently_stuck? && @stuck_on.master?
        return true if @sticky_master && @current_wrapper.master?

        return false if currently_stuck?
        return true if @sticky_slaves && @current_wrapper.slave?
        
        false
      end

      # based on this sql command, should we require the master connection be used?
      # override this if you'd like to globally set to master in a block
      def requires_master?(sql)
        return true if @master_forced
        !(!!(sql.to_s.downcase =~ SQL_SLAVE_MATCHER))
      end


      # we need a concept of the current slave for iteration purposes. this resets that current to the first slave
      def reset_current_slave
        @current_slave = next_slave || @slaves.first
      end


      # decorate our database adapters to invoke our execute before they invoke their own
      def decorate_connections!
        all_wrappers.each do |wrapper|
          decorate_connection(wrapper)
        end
      end

      # extends the connection with the ConnectionDecorator functionality
      # also passes a reference of ourself to the underlying connection
      # this reference is then used to ensure we can hijack underlying execute() calls
      def decorate_connection(wrapper)
        info("Decorated connection: #{wrapper}")
        con = wrapper.connection
        con.extend ::Makara::ConnectionWrapper::ConnectionDecorator
        con.makara_adapter = self
        con
      end

      # logging helpers
      %w(info error warn).each do |log_method|
        class_eval <<-LOG_METH, __FILE__, __LINE__ + 1
          def #{log_method}(msg)
            return unless @verbose
            msg = "\\e[34m[Makara]\\e[0m \#{msg}"
            ActiveRecord::Base.logger.#{log_method}(msg)
          end
        LOG_METH
      end

    end
  end
end