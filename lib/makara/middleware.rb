require 'rack'

# Persists the Makara::Context across requests ensuring the same master pool is used on the subsequent request.
# Simply sets the cookie with the current context and the status code of this request. The next request then sets
# the Makara::Context's previous context based on the the previous request. If a redirect is encountered the middleware
# will defer generation of a new context until a non-redirect request occurs.

module Makara
  class Middleware

    HEADER_IDENTIFIER = "X-Mkra-Ctxt"
    READ_HEADER_IDENTIFIER = "HTTP_X_MKRA_CTXT"
    COOKIE_IDENTIFIER = '_mkra_ctxt'


    def initialize(app)
      @app = app
    end


    def call(env)
      return @app.call(env) if ignore_request?(env)

      Makara::Context.set_previous previous_context(env)
      Makara::Context.set_current new_context(env)

      # Not writing to cache so we don't stick to master on next queries unless there really was a write that went to the DB.
      Makara.stick_to_master!(write_to_cache: false) if env["REQUEST_METHOD"] != "GET"

      status, headers, body = @app.call(env)

      store_context(status, headers)

      [status, headers, body]
    ensure
      cleanup_thread_caches
    end


    protected

    def cleanup_thread_caches
      Makara::Context.clear_stick_to_master_until
    end

    # ignore asset paths
    # consider allowing a filter proc to be provided in an initializer
    def ignore_request?(env)
      if defined?(Rails)
        if env['PATH_INFO'].to_s =~ /^#{Rails.application.config.assets.prefix}/
          return true
        end
      end
      false
    end


    # generate a new context based on the request
    def new_context(env)
      makara_context, makara_status, read_from_master_until = makara_values(env)

      now = Time.now.to_i
      # We still have to stick to master in this query.
      if read_from_master_until.to_i >= now
        # Prevent abuse by making sure max value is the master_ttl
        ttl = [read_from_master_until.to_i - now, Makara.master_ttl].min
        Makara.stick_to_master!(ttl: ttl)
      end

      context = nil

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
    # response in the format: $digest--$status--$read_from_master_until
    def makara_values(env)
      regex = /#{COOKIE_IDENTIFIER}=([\-a-z0-9A-Z]+)/

      env['HTTP_COOKIE'].to_s =~ regex
      return $1.split('--') if $1

      if env[READ_HEADER_IDENTIFIER]
        values = env[READ_HEADER_IDENTIFIER].split("--")
        return values if values.last.to_i >= Time.now.to_i
      end

      [nil, nil, nil]
    end


    # push the current context into cookie + header
    def store_context(status, header)
      stick_to_master_until = Makara::Context.stick_to_master_until.to_i
      now = Time.now.to_i

      # We should not stick to master anymore for this client
      return if stick_to_master_until < now

      ttl = [stick_to_master_until - now, Makara.master_ttl].min

      value = "#{Makara::Context.get_current}--#{status}--#{stick_to_master_until}"
      secure = defined?(Rails) && (Rails.env.production? || Rails.env.staging?)
      cookie_value = {
        :path => '/',
        :value => value,
        :http_only => true,
        :secure => secure,
        :max_age => ttl.to_s
      }

      header[HEADER_IDENTIFIER] = value
      Rack::Utils.set_cookie_header!(header, COOKIE_IDENTIFIER, cookie_value)
    end
  end
end
