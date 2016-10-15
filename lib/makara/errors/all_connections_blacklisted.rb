module Makara
  module Errors
    class AllConnectionsBlacklisted < MakaraError

      def initialize(pool, errors)
        errors = [*errors]
        messages = errors.empty? ? 'No error details' : errors.map(&:message).join(' -> ')
        super "[Makara/#{pool.role}] All connections are blacklisted -> " + messages
      end

    end
  end
end
