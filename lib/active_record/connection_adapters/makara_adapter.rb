module ActiveRecord
  
  class Base

    def self.makara_connection(config)
      wrappers = ::Makara::ConfigParser.each_config(config) do |db_config|
        connection = underlying_connection_for(db_config)                
        ::Makara::Connection::Wrapper.new(connection)
      end

      raise "[Makara] You must include at least one connection that serves as a master" unless wrappers.any?(&:master?)

      ::ActiveRecord::ConnectionAdapters::MakaraAdapter.new(wrappers, config)
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

      attr_reader :current_wrapper

      SQL_SLAVE_KEYWORDS      = ['select', 'show tables', 'show fields', 'describe', 'show database', 'show schema', 'show view', 'show index']
      SQL_SLAVE_MATCHER       = /^(#{SQL_SLAVE_KEYWORDS.join('|')})/
      MASS_DELEGATION_METHODS = %w(active? reconnect! disconnect! reset!)

      def initialize(wrappers, options = {})

        # sticky master by default
        @sticky_master      = true
        @sticky_master      = !!options.delete(:sticky_master) if options.has_key?(:sticky_master)
    
        # sticky slaves by default
        @sticky_slave       = true
        @sticky_slave       = !!options.delete(:sticky_slaves) if options.has_key?(:sticky_slaves)
        @sticky_slave       = !!options.delete(:sticky_slave) if options.has_key?(:sticky_slave)
    
        @verbose            = !!options.delete(:verbose)
            
        @master             = ::Makara::Connection::Group.new(wrappers.select(&:master?))
        @slave              = ::Makara::Connection::Group.new(wrappers.select(&:slave?))

        @exception_handler  = ::Makara::Connection::ErrorHandler.new(self)

        decorate_connections!

      end

      def verify!
        all_wrappers.each do |wrapper|
          wrapper.connection.verify! unless wrapper.blacklisted?
        end
      end

      # these methods must be forwarded on all adapters
      MASS_DELEGATION_METHODS.each do |aggregate_method|

        class_eval <<-AGG_METHOD, __FILE__, __LINE__ + 1
          def #{aggregate_method}(*args)
            send_to_all!(:#{aggregate_method}, *args)
          end
        AGG_METHOD

      end


      # the execute method which routes it's call to the correct underlying adapter.
      # if we're already stuck on a connection, continue using it. if we want to be stuck on a connection, stick to it.
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
        
        # handle the exception properly
        @exception_handler.handle(e)

        # do it again!
        retry
      end


      # temporarily force master within the block provided
      def with_master
        old_value = @master_forced
        force_master!        
        yield
      ensure
        @master_forced = old_value
        info("Releasing forced master")
      end

      # if we don't know how to handle it, pass to a master
      def method_missing(method_name, *args, &block)
        @master.any.connection.send(method_name, *args, &block)
      end

      def respond_to?(method_name, include_private = false)
        super || @master.any.connection.respond_to?(method_name, include_private)
      end

      # provide an easy way to get the name of the current wrapper
      # especially useful for logging
      def current_wrapper_name
        @current_wrapper.try(:name)
      end

      # provide a way for things like the middleware to determine if we're currently using a master wrapper
      def currently_master?
        !!@current_wrapper.try(:master?)
      end

      def sticky_master?
        @sticky_master
      end

      def sticky_slave?
        @sticky_slave
      end

      # if we want to unstick the current connection (request is over, testing, etc)
      def unstick!
        info("Unstuck: #{@current_wrapper}")
        @stuck_on = nil
      end

      # are we currently hijacking an execute call and choosing the appropriate connection?
      def hijacking_execute?
        !!@hijacking_execute
      end

      # force us to use a master connection
      def force_master!
        @master_forced = true
        info("Forcing master")
      end


      def inspect
        "#<#{self.class.name} current: #{@current_wrapper.try(:name)}, sticky: [#{[@sticky_master ? 'master(s)' : nil, @sticky_slave ? 'slave(s)' : nil].compact.join(', ')}], verbose: #{@verbose}, master: #{@master.length}, slaves: #{@slave.length} >"
      end


      protected

      # send the provided method and args to all the underlying adapters
      def send_to_all!(method_name, *args)
        all_connections.each do |con|
          con.send(method_name, *args)
        end
      end

      # provide a way to access all our wrappers
      def all_wrappers
        [@master, @slave].map(&:wrappers).flatten.compact
      end

      # all the underlying adapters
      def all_connections
        all_wrappers.map(&:connection)
      end


      # the connection wrapper which should be chosen based on the sql we've provided.
      # if we're dealing with a sql statement which requires master access, use it.
      # otherwise, let's use the currently stuck connection, the next available slave, or the master connection
      def current_wrapper_for(sql)
        if requires_master?(sql)
          @stuck_on.try(:master?) ? @stuck_on : @master.next
        else
          @stuck_on || @slave.next || @master.next
        end
      end

      # denote that we're hijacking an execute call
      def hijacking_execute!
        @hijacking_execute = true
        yield
      ensure
        @hijacking_execute = false
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
        
        return false  if currently_stuck?   && @stuck_on.master?
        return true   if @sticky_master     && @current_wrapper.master?

        return false  if currently_stuck?
        return true   if @sticky_slave      && @current_wrapper.slave?
        
        false
      end

      # based on this sql command, should we require the master connection be used?
      # override this if you'd like to globally set to master in a block
      def requires_master?(sql)
        return true if @master_forced
        !(!!(sql.to_s.downcase =~ SQL_SLAVE_MATCHER))
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
        con.extend ::Makara::Connection::Decorator
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