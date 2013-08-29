module Makara2
  class Context
    class << self


      def generate
        SecureRandom.hex
      end


      def get_previous
        @previous_context || 'default_previous'
      end

      def set_previous(context)
        @previous_context = context
      end


      def get_current
        @current_context || 'default_current'
      end

      def set_current(context)
        @current_context = context
      end

    end
  end
end