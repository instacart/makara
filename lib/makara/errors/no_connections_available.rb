module Makara
  module Errors
    class NoConnectionsAvailable < ::StandardError

      attr_reader :role

      def initialize(role)
        @role = role
        super "[Makara] No connections are available in the #{role} pool"
      end

    end
  end
end
