module Makara
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
