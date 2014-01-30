module Makara
  module Errors
    class InitialConnectionFailure < ::StandardError

      def initialize(connection, error)
        name = connection._makara_name
        super "[Makara] Failed to instantiate connection: #{name} -> #{error.message}"
      end

    end
  end
end
