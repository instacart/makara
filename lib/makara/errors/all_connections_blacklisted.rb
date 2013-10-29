module Makara
  module Errors
    class AllConnectionsBlacklisted < StandardError

      def initialize(error)
        super "[Makara] All connections are blacklisted - #{error.message}"
      end

    end
  end
end
