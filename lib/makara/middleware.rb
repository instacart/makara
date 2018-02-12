require 'rack'

# Persists the Makara::Context across requests ensuring the same master pool is used on subsequent requests.
module Makara
  class Middleware

    def initialize(app, cookie_options = {})
      @app = app
      @cookie_options = cookie_options
    end

    def call(env)
      return @app.call(env) if ignore_request?(env)

      request = Rack::Request.new(env)
      Makara::Context.init(request)

      status, headers, body = @app.call(env)

      Makara::Context.commit(headers, @cookie_options)

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
  end
end
