module Makara
  module StateCache
    class Cookie < Abstract

      def get(key)
        return unless @request

        @request.cookies[key]
      end

      def set(key, value, ttl)
        return unless @response
        @response.set_cookie(key, {:value => value, :path => '/', :expires => Time.now + ttl})
      end

      def del(key)
        return unless @response

        if @response.header['Set-Cookie'].present? 
          @response.delete_cookie(key)
        end
      end

    end
  end
end