require 'active_support/core_ext/hash/keys'

module Makara2
  class Pool

    def initialize(config)
      @config         = config.symbolize_keys
      @context        = Makara2::Context.get_current
      @connections    = []
      @current_idx    = 0
      @error_handler  = Makara2::ErrorHandler.new
    end


    def completely_blacklisted?
      @connections.each do |connection|
        return false unless connection.blacklisted?
      end
      true
    end


    def add(connection, config = @config)
      wrapper = Makara2::ConnectionWrapper.new(connection, config)
      wrapper._makara_weight.times{ @connections << wrapper }

      if should_shuffle?
        @connections.shuffle!
        @current_idx = rand(@connections.length)
      end

      wrapper
    end


    def current_connection_name
      con = @connections[@current_idx]
      name = con._makara_name
      name ||= @current_idx + 1 if @connections.length > 1
      name
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


    def any
      con = self.next
      if block_given?
        yield con
      else
        con
      end
    end


    def provide
      provided_connection = self.next

      if provided_connection
        
        @error_handler.handle do
          yield provided_connection
        end

      else
        raise Makara2::Errors::AllConnectionsBlacklisted
      end


    rescue Makara2::Errors::BlacklistConnection => e
      blacklist!
      retry
    end


    protected



    def next

      if Makara2::Context.get_current == @context
        con = @connections[@current_idx]
        return con unless con.blacklisted? 
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
    # optionally, store the position we're returning
    def safe_value(idx, stick = false)
      con = @connections[idx]
      return nil if con.blacklisted?

      if stick
        @current_idx = idx
        @context = Makara2::Context.get_current
      end

      con
    end


    def blacklist!
      @connections[@current_idx].blacklist!
    end


    def should_shuffle?
      true
    end

  end
end