module Makara
  module Connection
    class Group

      attr_reader :wrappers

      delegate :length, :size, :empty?, :blank?, :to => :wrappers

      def initialize(wrappers, sticky = true)
        @wrappers     = wrappers
        @current_idx  = 0
      end

      def reset!
        @current_idx = 0
      end

      def any
        @wrappers.first
      end

      def next

        return nil if self.empty?

        if self.singular?
          return safe_value(@current_idx, true)
        end

        idx = next_index(@current_idx)

        while safe_value(idx).nil?
          idx = next_index(idx)

          #we've looped all the way around
          if idx == @current_idx 
            return safe_value(idx, true) 
          end

        end

        safe_value(idx, true)
      end

      def current
        @wrappers[@current_idx]
      end

      protected

      def next_index(idx)
        idx = idx + 1
        idx = 0 if idx >= @wrappers.length
        idx 
      end

      def safe_value(idx, store_index = false)
        @current_idx = idx if store_index
        con = @wrappers[idx]
        con.blacklisted? ? nil : con
      end

      def singular?
        @wrappers.length <= 1
      end

    end
  end
end