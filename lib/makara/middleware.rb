require 'rack'
require 'rack/request'

module Makara
  class Middleware

    def initialize(app)
      @app = app
    end

    def call(env)

      return @app.call(env) unless Makara.in_use?

      request = Rack::Request.new(env)

      indexes = indexes_using_master(request)

      status, headers, body = Makara.with_master(indexes) do
        @app.call(env)
      end

      response = Rack::Response.new(body, status, headers)

      store_master_cookie!(request, response)

      response.finish

    ensure
      Makara.to_all(:unstick!)
    end

    protected

    def cookie_name
      [Makara.namespace, 'makara-master-indexes'].compact.join('_')
    end

    def indexes_using_master(request)
      cookie_value = request.cookies[cookie_name]
      return [] if cookie_value.blank?
      cookie_value.split(',').map(&:to_i)
    end

    def store_master_cookie!(request, response)
      if request.get?
        return if [301, 302].include?(response.status.to_i)

        if response.header['Set-Cookie'].present? 
          response.delete_cookie(cookie_name)
        end
      else
        current_indexes = Makara.indexes_currently_using_master
        unless current_indexes.empty?
          response.set_cookie(cookie_name, {:value => current_indexes.join(','), :path => '/', :expires => Time.now + 5})
        end
      end
    end

  end
end