module Makara
  module StateCache
    class Abstract

      class << self
        def connect(options = {})
          true
        end
      end

      def initialize(request, response)
        @request  = request
        @response = response
      end

      def get(key)
        nil
      end

      def set(key, value, ttl)
        nil
      end

      def del(key)
        nil
      end

      protected

      def with_session_key(base_key)
        session_id = @request.try(:session).try(:[], 'session_id')
        return nil unless session_id

        yield "#{session_id}-#{base_key}"
      end

    end
  end
end