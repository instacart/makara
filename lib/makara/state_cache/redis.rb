require 'redis'

module Makara
  module StateCache
    class Redis < Abstract

      class << self

        def connect(options = {})
          @client ||= ::Redis.new(options)
          true
        end

        def client
          @client || ::Redis.current
        end

      end

      def get(key)
        with_session_key(key) do |session_key|
          client.get(session_key)
        end
      end

      def set(key, value, ttl)
        with_session_key(key) do |session_key|
          client.setex(session_key, ttl, value)
        end
      end

      def del(key)
        with_session_key(key) do |session_key|
          client.del(session_key)
        end
      end

      protected

      def client
        self.class.client
      end

    end
  end
end