require 'rack'

module Makara2
  class Middleware

    COOKIE_NAME = '_mkra_ctxt'


    def initialize(app)
      @app = app
    end


    def call(env)

      return @app.call(env) if ignore_request?(env)
      
      Makara2::Context.set_previous previous_context(env)
      Makara2::Context.set_current new_context(env)

      status, headers, body = @app.call(env)

      store_context(status, headers)

      [status, headers, body]
    end


    protected


    def ignore_request?(env)
      if defined?(Rails)
        if env['PATH_INFO'].to_s =~ /^#{Rails.application.config.assets.prefix}/
          return true
        end
      end
      false
    end


    def new_context(env)

      cookie_context, cookie_status = cookie_values(env)

      context = nil

      # if the previous request was a redirect, let's keep that context
      if cookie_status.to_s =~ /^3/ # 300+ redirect
        context = cookie_context
      end

      context ||= Makara2::Context.get_current if env['rack.test']
      context ||= Makara2::Context.generate(env["action_dispatch.request_id"])
      context
    end


    def previous_context(env)
      context = cookie_values(env).first
      context ||= Makara2::Context.get_previous if env['rack.test']
      context ||= Makara2::Context.generate
      context
    end

    def cookie_values(env)
      env['HTTP_COOKIE'].to_s =~ /#{COOKIE_NAME}=([\-a-z0-9A-Z]+)/
      return $1.split('--') if $1
      [nil, nil]
    end


    def store_context(status, header)

      cookie_value = {
        path: '/',
        value: "#{Makara2::Context.get_current}--#{status}",
        http_only: true,
        max_age: '5'
      }

      Rack::Utils.set_cookie_header!(header, COOKIE_NAME, cookie_value)
    end
  end
end