require 'rack'
require 'rack/request'

module Makara
  class Middleware

    def initialize(app)
      @app = app
    end

    def call(env)

      request = Rack::Request.new(env)

      force_necessary_ids_to_master!(request)

      status, headers, body = @app.call(env)

      response = Rack::Response.new(body, status, headers)

      store_forced_ids!(request, response)

      response.finish

    ensure
      Makara.release_forced_ids!
      Makara.release_stuck_ids!
    end

    protected

    def cache_key
      'master-ids'
    end

    def state_cache(request, response)
      Makara::StateCache.for(request, response)
    end

    def force_necessary_ids_to_master!(request)
      value = state_cache(request, nil).get(cache_key)
      return if value.blank?
      ids = value.split(',')
      ids.each{|id| Makara.force_to_master!(id) }
    end

    def store_forced_ids!(request, response)
      if [301, 302].include?(response.status.to_i)
        currently_forced = Makara.currently_forced_ids
        unless currently_forced.empty?
          state_cache(request, response).set(cache_key, currently_forced.join(','), 5)
        end
      else
        currently_stuck = Makara.currently_stuck_ids

        if currently_stuck.empty?
          state_cache(request, response).del(cache_key)
        else
          state_cache(request, response).set(cache_key, currently_stuck.join(','), 5)
        end
      end
    end

  end
end