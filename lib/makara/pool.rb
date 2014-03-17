require 'active_support/core_ext/hash/keys'

# Wraps a collection of similar connections and chooses which one to use
# Uses the Makara::Context to determine if the connection needs rotation.
# Provides convenience methods for accessing underlying connections

module Makara
  class Pool

    # there are cases when we understand the pool is busted and we essentially want to skip
    # all execution
    attr_writer :disabled
    attr_reader :blacklist_errors
    attr_reader :role

    def initialize(role, proxy)
      @role             = role
      @proxy            = proxy
      @context          = Makara::Context.get_current
      @connections      = []
      @blacklist_errors = []
      @current_idx      = 0
      @disabled         = false
    end


    def completely_blacklisted?
      @connections.each do |connection|
        return false unless connection._makara_blacklisted?
      end
      true
    end


    # Add a connection to this pool, wrapping the connection with a Makara::ConnectionWrapper
    def add(config, &block)
      config[:name] ||= "#{@role}/#{@connections.length + 1}"

      wrapper = Makara::ConnectionWrapper.new(@proxy, config, &block)

      # the weight results in N references to the connection, not N connections
      wrapper._makara_weight.times{ @connections << wrapper }

      if should_shuffle?
        # randomize the connections so we don't get peaks and valleys of load
        @connections.shuffle!

        # then start at a random spot in the list
        @current_idx = rand(@connections.length)
      end

      wrapper
    end


    # send this method to all available nodes
    def send_to_all(method, *args)
      ret = nil
      provide_each do |con|
        ret = con.send(method, *args)
      end
      ret
    end

    # provide all available nodes to the given block
    def provide_each
      idx = @current_idx
      begin
        provide(false) do |con|
          yield con
        end
      end while @current_idx != idx
    end

    # Provide a connection that is not blacklisted and connected. Handle any errors
    # that may occur within the block.
    def provide(allow_stickiness = true)
      provided_connection = self.next(allow_stickiness)

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

      # if we don't have any connections, we should report the issue.
      else
        @blacklist_errors = []
        raise Makara::Errors::NoConnectionsAvailable.new(@role) unless @disabled
      end

    # when a connection causes a blacklist error within the provided block, we blacklist it then retry
    rescue Makara::Errors::BlacklistConnection => e
      @blacklist_errors.insert(0, e)
      provided_connection._makara_blacklist!
      retry

    # when a connection cannot be connected we blacklist the node.
    # we don't retry because the failure came from instantiation of the underlying connection, not the block
    rescue Makara::Errors::InitialConnectionFailure => e
      provided_connection._makara_blacklist!
    end



    protected



    # have we connected to any of the underlying connections.
    def connection_made?
      @connections.any?(&:_makara_connected?)
    end


    # Get the next non-blacklisted connection. If the proxy is setup
    # to be sticky, provide back the current connection assuming it is
    # not blacklisted.
    def next(allow_stickiness = true)

      if allow_stickiness && @proxy.sticky && Makara::Context.get_current == @context
        con = safe_value(@current_idx)
        return con if con
      end

      idx = @current_idx
      begin

        idx = next_index(idx)

        # if we've looped all the way around, return our safe value
        return safe_value(idx, true) if idx == @current_idx

      # while our current safe value is dangerous
      end while safe_value(idx).nil?

      # store our current spot and return our safe value
      safe_value(idx, true)
    end


    # next index within the bounds of the connections array
    # loop around when the end is hit
    def next_index(idx)
      idx = idx + 1
      idx = 0 if idx >= @connections.length
      idx
    end


    # return the connection if it's not blacklisted
    # otherwise return nil
    # optionally, store the position and context we're returning
    def safe_value(idx, stick = false)
      con = @connections[idx]
      return nil unless con
      return nil if con._makara_blacklisted?

      if stick
        @current_idx = idx
        @context = Makara::Context.get_current
      end

      con
    end


    # stub in test mode to ensure consistency
    def should_shuffle?
      true
    end

  end
end
