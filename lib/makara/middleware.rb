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
      set_current_context(env)

      status, headers, body = @app.call(env)
      store_new_context(headers)

      [status, headers, body]
    end


    protected

    def set_current_context(env)
      context_data = Makara::Cookie.fetch(Rack::Request.new(env))
      Makara::Context.set_current(context_data)
    end

    def store_new_context(headers)
      Makara::Cookie.store(Makara::Context.next, headers, @cookie_options)
    end

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
