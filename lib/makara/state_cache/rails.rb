module Makara
  module StateCache
    class Rails < Abstract

      def get(key)
        with_session_key(key) do |session_key|
          ::Rails.cache.read(session_key)
        end
      end

      def set(key, value, ttl)
        with_session_key(key) do |session_key|
          ::Rails.cache.write(session_key, value, :expires_in => ttl)
        end
      end

      def del(key)
        with_session_key(key) do |session_key|
          ::Rails.cache.delete(session_key)
        end
      end

    end
  end
end