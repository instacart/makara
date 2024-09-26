module Makara
  module Errors
    class DenylistedWhileInTransaction < MakaraError
      attr_reader :role

      def initialize(role)
        @role = role
        super "[Makara] Denylisted while in transaction in the #{role} pool"
      end
    end
  end
end
