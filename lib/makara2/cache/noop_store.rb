module Makara2
  module Cache
    class NoopStore
      
      def read(key)
        nil
      end

      def write(key, value, options = {})
        nil
      end

    end
  end
end