module Makara
  module Connection

    # represents a group of connection wrappers
    # understands how to iterate over the wrappers when requested
    # provides
    class Group

      attr_reader :wrappers

      delegate :length, :size, :empty?, :blank?, :to => :wrappers

      def initialize(wrappers, sticky = true)
        @wrappers     = wrappers
        @current_idx  = 0
      end

      # doesn't take into account blacklisting, just returns one of our values
      def any
        current || @wrappers.first
      end

      # grabs the next non-blacklisted wrapper
      # if all wrappers are blacklisted, returns nil
      def next

        # bypass the simple situation
        return safe_value(@current_idx, true) if self.singular?
        
        # start at our current position
        idx = @current_idx  
        begin
          # grab the next possible index
          idx = next_index(idx)

          # if we've looped all the way around, return our safe value
          return safe_value(idx, true) if idx == @current_idx

          # while our current safe value is dangerous
        end while safe_value(idx).nil?
 

        # store our current spot and return our safe value
        safe_value(idx, true)
      end

      protected
      
      def current
        @wrappers[@current_idx]
      end

      # next index within the bounds of the wrappers array
      # loop around when the end is hit
      def next_index(idx)
        idx = idx + 1
        idx = 0 if idx >= @wrappers.length
        idx 
      end

      # return the wrapper if it's not blacklisted
      # otherwise return nil
      # optionally, store the position we're returning
      def safe_value(idx, store_index = false)
        @current_idx = idx if store_index
        con = @wrappers[idx]
        con.try(:blacklisted?) ? nil : con
      end

      # are we dealing with a situation where iteration is pointless?
      def singular?
        @wrappers.length <= 1
      end

    end
  end
end