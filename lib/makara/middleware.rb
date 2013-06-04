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

    def cache_key
      [Makara.namespace, 'makara-master-indexes'].compact.join('_')
    end

    def state_cache(request, response)
      Makara.state_cache(request, response)
    end

    def indexes_using_master(request)
      cookie_value = state_cache(request, nil).get(cache_key)
      return [] if cookie_value.blank?
      cookie_value.split(',').map(&:to_i)
    end

    def store_master_cookie!(request, response)
      if request.get?
        return if [301, 302].include?(response.status.to_i)

        state_cache(request, response).del(cache_key)
      else
        current_indexes = Makara.indexes_currently_using_master
        unless current_indexes.empty?
          state_cache(request, response).set(cache_key, current_indexes.join(','), 5)
        end
      end
    end

  end
end