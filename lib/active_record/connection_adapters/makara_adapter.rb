module ActiveRecord
  
  class Base

    def self.makara_connection(config)
      underlying_connections = ::Makara::ConfigParser.each_config(config) do |db_config|
        underlying_connection_for(db_config)
      end

      ::ActiveRecord::ConnectionAdapters::MakaraAdapter.new(underlying_connections, config)
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

      # use the master connections class to determine what underlying visitor_for should be used.
      def self.visitor_for(pool)
        master_conf = ::Makara::ConfigParser.master_config(pool.spec.config)
        return AbstractAdapter.visitor_for(pool) unless master_conf
        adapter_name = master_conf[:db_adapter] || master_conf[:adapter]
        "ActiveRecord::ConnectionAdapters::#{adapter_name.to_s.classify}Adapter".constantize.visitor_for(pool)
      end

      attr_reader :current_wrapper, :id, :namespace

      SQL_SLAVE_KEYWORDS      = ['select', 'show tables', 'show fields', 'describe', 'show database', 'show schema', 'show view', 'show index']
      SQL_SLAVE_MATCHER       = /^(#{SQL_SLAVE_KEYWORDS.join('|')})/

      MASS_DELEGATION_METHODS = %w(reconnect! disconnect! reset!)
      MASS_ANY_DELEGATION_METHODS = %w(active?)

      def initialize(connections, options = {})

        wrappers = connections.map{|con| ::Makara::Connection::Wrapper.new(self, con) }

        raise "[Makara] You must include at least one connection that serves as a master" unless wrappers.any?(&:master?)

        connections.each do |con|
          con.extend ::Makara::Connection::Decorator
          con.makara_adapter = self
          con.makara_adapter # ensures that respond_to?() catches up
        end

        @verbose            = !!options[:verbose]

        @id                 =  options[:id] || 'default'
        @namespace          =  options[:namespace]

        # sticky master by default
        @sticky_master      = true
        @sticky_master      = !!options[:sticky_master]   if options.has_key?(:sticky_master)
    
        # sticky slaves by default
        @sticky_slave       = true
        @sticky_slave       = !!options[:sticky_slaves]   if options.has_key?(:sticky_slaves)
        @sticky_slave       = !!options[:sticky_slave]    if options.has_key?(:sticky_slave)

        @master             = ::Makara::Connection::Group.new(wrappers.select(&:master?))
        @slave              = ::Makara::Connection::Group.new(wrappers.select(&:slave?))

        @exception_handler  = ::Makara::Connection::ErrorHandler.new(self)

        Makara.register_adapter(self)
      end

      # not using any?(:meth) because i don't want it short-circuited.
      MASS_ANY_DELEGATION_METHODS.each do |meth|
        class_eval <<-DEL_METHOD, __FILE__, __LINE__ + 1
          def #{meth}
            info("[\#{@id}] Sending #{meth} to all connections and evaluating as any?")
            hijacking! do
              all_connections.select(&:#{meth}).present?
            end
          end
        DEL_METHOD
      end

      # these methods must be forwarded on all adapters
      MASS_DELEGATION_METHODS.each do |aggregate_method|
        class_eval <<-AGG_METHOD, __FILE__, __LINE__ + 1
          def #{aggregate_method}(*args)
            info("[\#{@id} Sending #{aggregate_method} to all connections")
            send_to_all!(:#{aggregate_method}, *args)
          end
        AGG_METHOD
      end


      # the execute method which routes it's call to the correct underlying adapter.
      # if we're already stuck on a connection, continue using it. if we want to be stuck on a connection, stick to it.
      def execute(sql, name = nil, binds = [])
        makara_block(sql) do |wrapper|

          ar = wrapper.method(:execute).arity
          
          # rails version compatability
          if ar >= 3 || ar <= -3
            wrapper.execute(sql, name, binds)
          else
            wrapper.execute(sql, name)
          end
        end
      end

      # the exec_query method which routes it's call to the correct underlying adapter.
      def exec_query(sql, name = 'SQL', binds = [])
        makara_block(sql) do |wrapper|
          wrapper.exec_query(sql, name, binds)
        end
      end


      # temporarily force master within the block provided
      def with_master
        previously_forced = forced_to_master?
        force_master!        
        yield
      ensure
        release_master! if previously_forced
      end

      # if we don't know how to handle it, pass to a master
      # cache a method declaration so we don't waste as much time the next time this is called
      def method_missing(method_name, *args, &block)
        class_eval <<-EV, __FILE__, __LINE__+1
          def #{method_name}(*args, &block)
            @master.any.connection.send(:#{method_name}, *args, &block)
          end
        EV
        send(method_name, *args, &block)
      end

      # TODO: consider using respond_to_missing? once 1.8.7 is gone
      def respond_to?(method_name, include_private = false)
        super || @master.any.connection.respond_to?(method_name, include_private)
      end

      # provide a way for things like the middleware to determine if we're currently using a master wrapper
      def currently_master?
        !!@current_wrapper.try(:master?)
      end

      # if we want to unstick the current connection (request is over, testing, etc)
      def unstick!
        @stuck_on = nil
        info("Unstuck: #{@current_wrapper}")
      end

      # denote that we're hijacking an execute call
      def hijacking!
        @hijacking = true
        yield
      ensure
        @hijacking = false
      end

      # are we currently hijacking an execute call and choosing the appropriate connection?
      def hijacking?
        !!@hijacking
      end

      # force us to use a master connection
      def force_master!
        @master_forced = true
        info("[#{@name}] Forcing master")
      end

      def forced_to_master?
        !!@master_forced
      end

      def release_master!
        @master_forced = false
        info("[#{@name}] Releasing master")
      end


      def inspect
        "#<#{self.class.name} current: #{@current_wrapper.try(:name)}, sticky: [#{[@sticky_master ? 'master(s)' : nil, @sticky_slave ? 'slave(s)' : nil].compact.join(', ')}], master: #{@master.length}, slaves: #{@slave.length} >"
      end


      def info(text)
        self.logger.try(:info, format_log(text)) if @verbose
      end
      def warn(text)
        self.logger.try(:warn, format_log(text))
      end
      def error(text)
        self.logger.try(:error, format_log(text))
      end


      protected

      def format_log(text)
        "[Makara] #{text}"
      end

      # send the provided method and args to all the underlying adapters
      # act like we're hijacking the execution so it doesn't raise the invocation back up to this adapter.
      def send_to_all!(method_name, *args)
        hijacking! do
          all_connections.each do |con|
            con.send(method_name, *args)
          end
        end
      end


      # provide a way to access all our wrappers
      def all_wrappers
        [@master, @slave].map(&:wrappers).flatten.compact.uniq
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
      def should_stick?(sql)

        return false  if ignore_stickiness?(sql)

        return false  if currently_stuck?   && @stuck_on.master?
        return true   if @sticky_master     && @current_wrapper.master?

        return false  if currently_stuck?
        return true   if @sticky_slave      && @current_wrapper.slave?
        
        false
      end

      def ignore_stickiness?(sql)
        s = sql.to_s.downcase
        return true if s =~ /^show ([\w]+ )?tables?/
        return true if s =~ /^show (full )?fields?/

        false
      end

      # based on this sql command, should we require the master connection be used?
      # override this if you'd like to globally set to master in a block
      def requires_master?(sql)
        return true if @master_forced
        !(!!(sql.to_s.downcase =~ SQL_SLAVE_MATCHER))
      end


      # yields the wrapper which should handle the provided sql.
      def makara_block(sql)
        # the connection wrapper that should handle the execute call
        @current_wrapper = current_wrapper_for(sql)

        # stick to it if we determine that's the right thing to do
        stick! if should_stick?(sql)

        # mark ourselves as being in a hijack block so we don't invoke this adapter's execute() unecessarily
        hijacking! do
          
          # hand off control to the wrapper
          yield @current_wrapper
        end

      # catch all exceptions for now, since we don't know what adapter we'll be using or how they'll be formatted
      rescue Exception => e
        
        # handle the exception properly
        @exception_handler.handle(e)

        # do it again! if all slaves are eventually blacklisted the master connection will raise the error.
        retry
      end


    end
  end
end