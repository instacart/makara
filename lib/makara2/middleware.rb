require 'rack'

module Makara2
  class Middleware

    COOKIE_NAME = '_mkra_ctxt'

    def initialize(app)
      @app = app
    end

    def call(env)
      Makara2::Context.set_previous previous_context(env)
      Makara2::Context.set_current new_context(env)

      status, headers, body = @app.call(env)

      store_context(headers)

      [status, headers, body]
    end

    protected

    def new_context(env)
      context = Makara2::Context.get_current if env['rack.test']
      context ||= env["action_dispatch.request_id"]
      context ||= Makara2::Context.generate
      context
    end

    def previous_context(env)
      env['HTTP_COOKIE'].to_s =~ /#{COOKIE_NAME}=([a-z0-9A-Z]+)/
      return $1 if $1

      context = $1
      context ||= Makara2::Context.get_previous if env['rack.test']
      context ||= Makara2::Context.generate
      context
    end

    def store_context(header)
      Rack::Utils.set_cookie_header!(header, COOKIE_NAME, Makara2::Context.get_current)
    end
  end
end