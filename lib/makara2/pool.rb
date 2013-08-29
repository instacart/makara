module Makara2
  class Pool

    def initialize(config)
      @config         = config
      @context        = Makara2::Context.get
      @connections    = []
      @current_idx    = 0
      @error_handler  = Makara2::ErrorHandler.new
    end


    def empty?
      @connections.empty?
    end


    def <<(connection)
      @connections << [connection, nil]
      @connections.shuffle!
      @current_idx = rand(@connections.length)
    end

    def each_connection
      @connections.each do |connection, blacklisted_until|
        yield connection
      end
    end


    def send_to_all(method, *args)
      @connections.each{|connection, blacklisted_until| connection.send(method, *args) }
    end


    def any
      yield @connections.first[0]
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


    protected



    def next
      if Makara2::Context.get == @context && @current_connection
        return @current_connection 
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
      con = @connections[idx][0]
      return nil if blacklisted?(idx)

      if stick
        @current_idx = idx
        @current_connection = con
        @context = Makara2::Context.get
      end

      con
    end


    def blacklisted?(idx)
      @connections[idx][1].to_i > Time.now.to_i
    end


    def blacklist!
      if @connections[@current_idx] == @current_connection
        @current_connection = nil
      end

      @connections[@current_idx][1] = Time.now.to_i + @config[:blacklist_duration]
    end

  end
end