module Makara2
  class Pool

    def initialize(config)
      @config         = config
      @connections    = []
      @blacklisted    = []
      @current_idx    = 0
      @error_handler  = Makara2::ErrorHandler.new
    end


    def empty?
      @connections.empty?
    end


    def <<(connection)
      @connections << connection
      @blacklisted << nil
      @current_idx = rand(@connections.length)
    end

    def each_connection
      @connections.each do |connection|
        yield connection
      end
    end


    def send_to_all(method, *args)
      @connections.each{|connection| connection.send(method, *args) }
    end


    def any
      yield @connections.first
    end


    def provide
      provided_connection = self.next

      if provided_connection
        
        @error_handler.handle do
          yield provided_connection
        end

      elsif self.empty?
        raise Makara2::Errors::NoConnectionsConfigured
      else
        raise Makara2::Errors::AllConnectionsBlacklisted
      end


    rescue Makara2::Errors::BlacklistConnection => e
      blacklist!
      retry
    end


    def stick
      previous_stuck_on = @stuck_on
      @stuck_on ||= self.next

      provide do |connection|
        yield connection
      end

    ensure
      @stuck_on = previous_stuck_on
    end



    protected



    def next
      return @stuck_on if @stuck_on
      
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
    def safe_value(idx, store_index = false)
      @current_idx = idx if store_index
      con = @connections[idx]
      blacklisted?(idx) ? nil : con
    end


    def blacklisted?(idx)
      @blacklisted[idx].to_i > Time.now.to_i
    end


    def blacklist!
      @blacklisted[@current_idx] = Time.now.to_i + @config[:blacklist_duration]
    end

  end
end