module Makara
  module Errors
    class BlacklistConnection < ::StandardError

      def initialize(connection, error)
        super "[Makara/#{connection._makara_name}] #{error.message}"
      end

    end
  end
end
