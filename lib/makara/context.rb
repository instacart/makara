require 'digest/md5'

# Keeps track of the current stickiness state for different Makara configurations
module Makara
  class Context
    attr_accessor :data

    IDENTIFIER = '_mkra_ctxt'

    DEFAULT_OPTIONS = {
      path: "/",
      http_only: true
    }

    def initialize(data)
      @data = data
      @dirty = false
    end

    def stick(config_id, ttl)
      data[config_id] = Time.now.to_f + ttl.to_f
      @dirty = true
    end

    def stuck?(config_id)
      data[config_id] && data[config_id] > Time.now.to_f
    end

    # Indicates whether there have been changes to the context that need
    # to be persisted when the request finishes
    def dirty?
      @dirty
    end

    def to_cookie_options
      max_age = (data.values.max - Time.now.to_f).ceil + 1
      value = data.collect { |config_id, ttl| "#{config_id}:#{ttl}" }.join('|')
      { :max_age => max_age, :value => value }
    end

    class << self
      def init(request)
        data = parse(request.cookies[IDENTIFIER].to_s)
        set(:makara_current_context, new(data))
      end

      # Called by `Proxy#stick_to_master!` to stick subsequent requests to
      # master when using the given config
      def stick(config_id, ttl)
        current.stick(config_id, ttl)
      end

      def stuck?(config_id)
        current.stuck?(config_id)
      end

      def commit(headers)
        if current.dirty?
          Rack::Utils.set_cookie_header! headers, IDENTIFIER, DEFAULT_OPTIONS.merge(current.to_cookie_options)
        end
      end

      protected
        def current
          get(:makara_current_context)
        end

        if Thread.current.respond_to?(:thread_variable_get)
          def get(key)
            Thread.current.thread_variable_get(key)
          end

          def set(key, value)
            Thread.current.thread_variable_set(key,value)
          end
        else
          def get(key)
            Thread.current[key]
          end

          def set(key, value)
            Thread.current[key]=value
          end
        end

      private
        # Pairs of {config_id}:{timestamp}, separated by "|"
        # config_id1:1518270031.3132212|config_id2:1518270030.313232 ..
        def parse(cookie_string)
          return {} if cookie_string.empty?

          states = cookie_string.split("|")
          states.each_with_object({}) do |state, data|
            config_id, timestamp = state.split(":")
            data[config_id] = timestamp.to_f if config_id && timestamp
          end
        end
    end
  end
end
