require 'active_support/core_ext/hash/keys'

# Wraps a collection of similar connections and chooses which one to use
# Provides convenience methods for accessing underlying connections

module Makara
  class Pool

    # there are cases when we understand the pool is busted and we essentially want to skip
    # all execution
    attr_accessor :disabled
    attr_reader :blacklist_errors
    attr_reader :role
    attr_reader :connections
    attr_reader :strategy

    def initialize(role, proxy)
      @role             = role
      @proxy            = proxy
      @connections      = []
      @blacklist_errors = []
      @disabled         = false
      @strategy         = proxy.strategy_for(role)
      @just_blacklisted_master = Hash.new
      @last_blacklisted_conn = Hash.new
    end


    def completely_blacklisted?
      @connections.each do |connection|
        return false unless connection._makara_blacklisted?
      end
      true
    end


    # Add a connection to this pool, wrapping the connection with a Makara::ConnectionWrapper
    def add(config)
      config[:name] ||= "#{@role}/#{@connections.length + 1}"

      connection = yield

      # already wrapped because of initial error
      if connection.is_a?(Makara::ConnectionWrapper)
        connection.config = config # to add :name
        wrapper = connection
      else
        wrapper = Makara::ConnectionWrapper.new(@proxy, connection, config)
      end

      @connections << wrapper
      @strategy.connection_added(wrapper)

      wrapper
    end

    # send this method to all available nodes
    # send nil to just yield with each con if there is block
    def send_to_all(method, *args, &block)
      ret = nil
      one_worked = false # actually found one that worked
      errors = []

      @connections.each do |con|
        next if con._makara_blacklisted?
        begin
          ret = @proxy.error_handler.handle(con) do
            if block
              yield con
            else
              con.send(method, *args)
            end
          end

          one_worked = true
        rescue Makara::Errors::BlacklistConnection => e
          errors.insert(0, e)
          con._makara_blacklist!
          record_master_blacklist(e, con)
        end
      end

      if !one_worked
        if connection_made?
          raise Makara::Errors::AllConnectionsBlacklisted.new(self, errors)
        else
          raise Makara::Errors::NoConnectionsAvailable.new(@role) unless @disabled
        end
      end

      ret
    end

    def handle_master_blacklists
      if @just_blacklisted_master[Thread.current.object_id]
        e = @just_blacklisted_master[Thread.current.object_id]
        @just_blacklisted_master[Thread.current.object_id] = false
        raise Makara::Errors::BlacklistConnectionOnMaster.new(@last_blacklisted_conn[Thread.current.object_id], e)
      end
    end

    def record_master_blacklist(error, connection)
      if self.role == "master"
        @just_blacklisted_master[Thread.current.object_id] = error
        @last_blacklisted_conn[Thread.current.object_id] = connection
      end
    end
    # Provide a connection that is not blacklisted and connected. Handle any errors
    # that may occur within the block.
    def provide
      provided_connection = self.next
      # nil implies that it's blacklisted
      if provided_connection
        handle_master_blacklists
        value = @proxy.error_handler.handle(provided_connection) do
          yield provided_connection
        end

        @blacklist_errors = []

        value

      # if we've made any connections within this pool, we should report the blackout.
      elsif connection_made?
        err = Makara::Errors::AllConnectionsBlacklisted.new(self, @blacklist_errors)
        @blacklist_errors = []
        raise err
      else
        raise Makara::Errors::NoConnectionsAvailable.new(@role) unless @disabled
      end

    # when a connection causes a blacklist error within the provided block, we blacklist it then retry
    rescue Makara::Errors::BlacklistConnection => e
      @blacklist_errors.insert(0, e)
      provided_connection._makara_blacklist!
      record_master_blacklist(e, provided_connection)
      retry
    end


    protected


    # have we connected to any of the underlying connections.
    def connection_made?
      @connections.any?(&:_makara_connected?)
    end


    # Get the next non-blacklisted connection. If the proxy is setup
    # to be sticky, provide back the current connection assuming it is
    # not blacklisted.
    def next
      if @proxy.sticky && @strategy.current
        @strategy.current
      else
        @strategy.next
      end
    end
  end
end
