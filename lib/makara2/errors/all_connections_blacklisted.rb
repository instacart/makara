module Makara2
  module Errors
    class AllConnectionsBlacklisted < StandardError

      def initialize
        super "[Makara2] All connections are blacklisted"
      end

    end
  end
end