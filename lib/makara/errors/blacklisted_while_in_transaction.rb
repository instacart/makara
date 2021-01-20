module Makara
  module Errors
    class BlacklistedWhileInTransaction < MakaraError
      attr_reader :role

      def initialize(role)
        @role = role
        super "[Makara] Blacklisted while in transaction in the #{role} pool"
      end
    end
  end
end
