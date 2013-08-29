module Makara2
  module Errors
    class BlacklistConnection < ::StandardError

      def initialize(error)
        super error.message
        @error = error
      end

    end
  end
end