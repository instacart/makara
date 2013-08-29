module Makara2
  class Context
    class << self

      def get
        @context || 'default'
      end

      def set(context)
        @context = context
      end

    end
  end
end