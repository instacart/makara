require 'timeout'
require 'redis'

module Makara
  module StateCaches
    class Redis < Abstract

      class << self

        def connect(options = {})
          @client ||= begin
            @timeout = options[:makara_timeout]
            ::Redis.new(options.except(:makara_timeout))
          end
          true
        end

        def client
          @client || ::Redis.current
        end

        def timeout
          @timeout || 1
        end

      end

      def get(key)
        with_session_key_and_timeout(key) do |session_key|
          client.get(session_key)
        end
      end

      def set(key, value, ttl)
        with_session_key_and_timeout(key) do |session_key|
          client.setex(session_key, ttl, value)
        end
      end

      def del(key)
        with_session_key_and_timeout(key) do |session_key|
          client.del(session_key)
        end
      end

      protected

      def client
        self.class.client
      end

      def with_session_key_and_timeout(key)
        Timeout::timeout(self.class.timeout) do
          with_session_key(key) do |session_key|
            yield session_key
          end
        end
      end

    end
  end
end