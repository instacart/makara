module Makara
  module Strategies
    class Abstract
      attr_reader :pool
      def initialize(pool)
        @pool = pool
        init
      end

      def init
        # explicit constructor
      end

      def connection_added(wrapper)
        # doesn't have to be implemented
      end

      def current
        # it's sticky - give the "curent" one
        Kernel.raise NotImplementedError
      end

      def next
        # rotate to the "next" one if you feel like it
        Kernel.raise NotImplementedError
      end
    end
  end
end
