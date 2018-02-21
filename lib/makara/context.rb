require 'digest/md5'

# Keeps track of the current stickiness state for different Makara configurations
module Makara
  class Context

    IDENTIFIER = '_mkra_stck'

    DEFAULT_OPTIONS = {
      path: "/",
      http_only: true
    }

    attr_accessor :data

    def initialize(data)
      @data = data
      @dirty = false
    end

    def stick(proxy_id, ttl)
      data[proxy_id] = Time.now.to_f + ttl.to_f
      @dirty = true
    end

    def stuck?(proxy_id)
      data[proxy_id] && !expired?(data[proxy_id])
    end

    # Indicates whether there have been changes to the context that need
    # to be persisted when the request finishes
    def dirty?
      @dirty
    end

    def release(proxy_id)
      @dirty ||= !!data.delete(proxy_id)
    end

    def release_expired
      previous_size = data.size
      data.delete_if { |_, timestamp| expired?(timestamp) }
      @dirty ||= previous_size != data.size
    end

    def release_all
      if self.data.any?
        self.data = {}
        @dirty = true
      end
    end

    def to_cookie_options
      max_age = if data.any?
        (data.values.max - Time.now.to_f).ceil + 1
      else
        0
      end

      value = data.collect { |proxy_id, ttl| "#{proxy_id}:#{ttl}" }.join('|')
      { :max_age => max_age, :value => value }
    end

    private

    def expired?(timestamp)
      timestamp <= Time.now.to_f
    end

    class << self
      def init(request)
        data = parse(request.cookies[IDENTIFIER].to_s)
        set(:makara_current_context, new(data))
      end

      # Called by `Proxy#stick_to_master!` to stick subsequent requests to
      # master when using the given config
      def stick(proxy_id, ttl)
        current.stick(proxy_id, ttl)
      end

      def stuck?(proxy_id)
        current.stuck?(proxy_id)
      end

      def commit(headers, cookie_options = {})
        current.release_expired
        if current.dirty?
          cookie = DEFAULT_OPTIONS.merge(cookie_options)
          Rack::Utils.set_cookie_header! headers, IDENTIFIER, cookie.merge(current.to_cookie_options)
        end
      end

      def release(proxy_id)
        current.release(proxy_id)
      end

      def release_all
        current.release_all
      end

      protected
      def current
        fetch(:makara_current_context) { new({}) }
      end

      def fetch(key)
        get(key) || set(key, yield)
      end

      if Thread.current.respond_to?(:thread_variable_get)
        def get(key)
          Thread.current.thread_variable_get(key)
        end

        def set(key, value)
          Thread.current.thread_variable_set(key, value)
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

      # Pairs of {proxy_id}:{timestamp}, separated by "|"
      # proxy_id1:1518270031.3132212|proxy_id2:1518270030.313232 ..
      def parse(cookie_string)
        return {} if cookie_string.empty?

        states = cookie_string.split("|")
        states.each_with_object({}) do |state, data|
          proxy_id, timestamp = state.split(":")
          data[proxy_id] = timestamp.to_f if proxy_id && timestamp
        end
      end
    end
  end
end
