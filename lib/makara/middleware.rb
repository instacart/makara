module Makara
  class Middleware

    def initialize(app)
      @app = app
    end

    def call(env)

      return @app.call(env) unless makara_connection

      @request = Rack::Request.new(env)

      status, headers, body = if should_force_database?
        makara_connection.with_master do
          @app.call(env)
        end
      else
        @app.call(env)
      end

      @response = Rack::Response.new(body, status, headers)

      store_master_cookie!

      @response.finish

    ensure
      makara_connection.try(:unstick!)
    end

    protected

    def should_force_database?
      database_to_force.present?
    end

    # currently just use master. flexibility coming soon.
    def database_to_force
      @request.cookies['makara-force-master']
    end

    def store_master_cookie!
      if @request.get?
        unless [301, 302].include?(@response.status.to_i)
          @response.set_cookie('makara-force-master', nil)
        end
      elsif makara_connection.sticky_master? && makara_connection.currently_master?
        @response.set_cookie('makara-force-master', makara_connection.current_wrapper_name)
      end
    end

    def makara_connection
      return nil unless ActiveRecord::Base.connection.respond_to?(:unstick!)
      ActiveRecord::Base.connection
    end

  end
end