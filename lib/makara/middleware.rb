require 'rack'

# Persists the Makara::Context across requests ensuring the same master pool is used on the subsequent request.
# Simply sets the cookie with the current context and the status code of this request. The next request then sets
# the Makara::Context's previous context based on the the previous request. If a redirect is encountered the middleware
# will defer generation of a new context until a non-redirect request occurs.

module Makara
  class Middleware

    IDENTIFIER = '_mkra_ctxt'

    DEFAULT_COOKIE = {
      :path => '/',
      :http_only => true,
      :max_age => '5'
    }

    def initialize(app, cookie_options = {})
      @app = app
      @cookie = DEFAULT_COOKIE.merge(cookie_options)
    end


    def call(env)

      return @app.call(env) if ignore_request?(env)

      Makara::Context.set_previous previous_context(env)
      Makara::Context.set_current new_context(env)

      status, headers, body = @app.call(env)

      store_context(status, headers)

      [status, headers, body]
    end


    protected


    # ignore asset paths
    # consider allowing a filter proc to be provided in an initializer
    def ignore_request?(env)
      if defined?(Rails) && Rails.try(:application).try(:config).try(:assets).try(:prefix)
        if env['PATH_INFO'].to_s =~ /^#{Rails.application.config.assets.prefix}/
          return true
        end
      end
      false
    end


    # generate a new context based on the request
    # if the previous request was a redirect, we keep the same context
    def new_context(env)

      makara_context, makara_status = makara_values(env)

      context = nil

      # if the previous request was a redirect, let's keep that context
      if makara_status.to_s =~ /^3/ # 300+ redirect
        context = makara_context
      end

      context ||= Makara::Context.get_current if env['rack.test']
      context ||= Makara::Context.generate(env["action_dispatch.request_id"])
      context
    end


    # pulls the previous context out of the request
    def previous_context(env)
      context = makara_values(env).first
      context ||= Makara::Context.get_previous if env['rack.test']
      context ||= Makara::Context.generate
      context
    end


    # retrieve the stored content from the cookie or query
    # The value contains the hexdigest and status code of the previous
    # response in the format: $digest--$status
    def makara_values(env)
      regex = /#{IDENTIFIER}=([\-a-z0-9A-Z]+)/

      env['HTTP_COOKIE'].to_s =~ regex
      return $1.split('--') if $1

      env['QUERY_STRING'].to_s =~ regex
      return $1.split('--') if $1

      [nil, nil]
    end


    # push the current context into the cookie
    # it should always be for the same path, only
    # accessible via http and live for a short amount
    # of time
    def store_context(status, headers)
      cookie = @cookie.merge(:value => "#{Makara::Context.get_current}--#{status}")
      Rack::Utils.set_cookie_header! headers, IDENTIFIER, cookie
    end
  end
end
