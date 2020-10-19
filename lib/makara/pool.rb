require 'active_support/core_ext/hash/keys'
require 'makara/strategies/shard_aware'

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
    attr_reader :shard_strategy_class
    attr_reader :default_shard

    def initialize(role, proxy)
      @role             = role
      @proxy            = proxy
      @connections      = []
      @blacklist_errors = []
      @disabled         = false
      if proxy.shard_aware_for(role)
        @strategy = Makara::Strategies::ShardAware.new(self)
        @shard_strategy_class = proxy.strategy_class_for(proxy.strategy_name_for(role))
        @default_shard = proxy.default_shard_for(role)
      else
        @strategy = proxy.strategy_for(role)
      end
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

    # Provide a connection that is not blacklisted and connected. Handle any errors
    # that may occur within the block.
    def provide
      attempt = 0
      begin
        provided_connection = self.next

        # nil implies that it's blacklisted
        if provided_connection

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
        in_transaction = self.role == "master" && provided_connection._makara_in_transaction?
        provided_connection._makara_blacklist!
        raise Makara::Errors::BlacklistedWhileInTransaction.new(@role) if in_transaction
        attempt += 1
        if attempt < @connections.length
          retry
        elsif connection_made?
          err = Makara::Errors::AllConnectionsBlacklisted.new(self, @blacklist_errors)
          @blacklist_errors = []
          raise err
        else
          raise Makara::Errors::NoConnectionsAvailable.new(@role) unless @disabled
        end
      end
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
      if @proxy.sticky && (curr = @strategy.current)
        curr
      else
        @strategy.next
      end
    end
  end
end
