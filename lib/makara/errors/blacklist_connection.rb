module Makara
  module Errors
    class BlacklistConnection < ::StandardError

      def initialize(connection, error)
        name = connection._makara_name
        super "[Makara] Blacklisted connection: #{name} -> #{error.message}"
      end

    end
  end
end
