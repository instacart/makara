require 'active_support/core_ext/hash/keys'

# Wraps a collection of similar connections and chooses which one to use
# Uses the Makara::Context to determine if the connection needs rotation.
# Provides convenience methods for accessing underlying connections

module Makara
  class Pool

    def initialize(role, proxy)
      @role           = role
      @proxy          = proxy
      @context        = Makara::Context.get_current
      @connections    = []
      @current_idx    = 0
    end


    def completely_blacklisted?
      @connections.each do |connection|
        return false unless connection._makara_blacklisted?
      end
      true
    end


    # Add a connection to this pool, wrapping the connection with a Makara::ConnectionWrapper
    def add(connection, config)
      config[:name] ||= "#{@role}/#{@connections.length + 1}"

      wrapper = Makara::ConnectionWrapper.new(connection, @proxy, config)
      wrapper._makara_weight.times{ @connections << wrapper }

      if should_shuffle?
        @connections.shuffle!
        @current_idx = rand(@connections.length)
      end

      wrapper
    end


    def each_connection
      @connections.each do |connection|
        yield connection
      end
    end


    def send_to_all(method, *args)
      ret = nil
      @connections.each{|connection| ret = connection.send(method, *args) }
      ret
    end


    # Provide a way to get any random connection out of the pool, not worrying about blacklisting
    def any
      con = @connections[rand(@connections.length)]
      if block_given?
        yield con
      else
        con
      end
    end


    # Provide a connection that is not blacklisted and handle any errors
    # that may occur within the block.
    def provide
      provided_connection = self.next

      if provided_connection

        @latest_blacklist_error = nil

        @proxy.error_handler.handle(provided_connection) do
          yield provided_connection
        end

      else
        raise Makara::Errors::AllConnectionsBlacklisted.new(@latest_blacklist_error)
      end


    rescue Makara::Errors::BlacklistConnection => e
      @latest_blacklist_error = e
      provided_connection._makara_blacklist!
      retry
    end


    protected


    # Get the next non-blacklisted connection. If the proxy is setup
    # to be sticky, provide back the current connection assuming it is
    # not blacklisted.
    def next

      if @proxy.sticky && Makara::Context.get_current == @context
        con = @connections[@current_idx]
        return con unless con._makara_blacklisted?
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
