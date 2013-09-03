module Makara
  module Errors
    class AllConnectionsBlacklisted < StandardError

      def initialize
        super "[Makara] All connections are blacklisted"
      end

    end
  end
end