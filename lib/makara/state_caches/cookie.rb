module Makara
  module StateCaches
    class Cookie < Abstract

      def get(key)
        return unless @request
        with_session_key(key) do |session_key|
          @request.cookies[session_key]
        end
      end

      def set(key, value, ttl)
        return unless @response
        with_session_key(key) do |session_key|
          @response.set_cookie(session_key, {:value => value, :path => '/', :expires => Time.now + ttl})
        end
      end

      def del(key)
        return unless @response

        if @response.header['Set-Cookie'].present?
          with_session_key(key) do |session_key| 
            @response.delete_cookie(session_key)
          end
        end
      end

      protected

      # in the case of the cookie store, the session is implied by the existence of the cookie.
      # so we don't need to worry about using the session id at all.
      def with_session_key(base_key)
        yield ['makara', Makara.namespace, base_key].compact.join('-')
      end

    end
  end
end