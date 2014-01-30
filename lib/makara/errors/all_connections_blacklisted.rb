module Makara
  module Errors
    class AllConnectionsBlacklisted < StandardError

      def initialize(error)
        super "[Makara] All connections are blacklisted - #{error.try(:message) || 'No error details'}"
      end

    end
  end
end
