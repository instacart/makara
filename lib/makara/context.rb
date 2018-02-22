require 'digest/md5'

# Keeps track of the current stickiness state for different Makara configurations
module Makara
  class Context
    attr_accessor :stored_data, :staged_data

    def initialize(context_data)
      @stored_data = context_data
      @staged_data = {}
      @dirty = @was_dirty = false
    end

    def stage(proxy_id, ttl)
      staged_data[proxy_id] = ttl.to_f
    end

    def stuck?(proxy_id)
      stored_data[proxy_id] && !expired?(stored_data[proxy_id])
    end

    def staged?(proxy_id)
      staged_data.key?(proxy_id)
    end

    def release(proxy_id)
      @dirty ||= !!stored_data.delete(proxy_id)
      staged_data.delete(proxy_id)
    end

    def release_all
      if self.stored_data.any?
        self.stored_data = {}
        # We need to track a change made to the current stored data
        # so we can commit it later
        @dirty = true
      end
      self.staged_data = {}
    end

    # Stores the staged data with an expiration time based on the current time,
    # and clears any expired entries. Returns true if any changes were made to
    # the current store
    def commit
      release_expired
      store_staged_data
      clean

      was_dirty?
    end

    private

    # Indicates whether there have been changes to the context that need
    # to be persisted when the request finishes
    def dirty?
      @dirty || staged_data.any?
    end

    def was_dirty?
      @was_dirty
    end

    def expired?(timestamp)
      timestamp <= Time.now.to_f
    end

    def release_expired
      previous_size = stored_data.size
      stored_data.delete_if { |_, timestamp| expired?(timestamp) }
      @dirty ||= previous_size != stored_data.size
    end

    def store_staged_data
      staged_data.each do |proxy_id, ttl|
        self.stored_data[proxy_id] = Time.now.to_f + ttl
      end
    end

    def clean
      @was_dirty = dirty?
      @dirty = false
      @staged_data = {}
    end

    class << self
      def set_current(context_data)
        set(:makara_current_context, new(context_data))
      end

      # Called by `Proxy#stick_to_master!` to use master in subsequent requests
      def stick(proxy_id, ttl)
        current.stage(proxy_id, ttl)
      end

      def stuck?(proxy_id)
        current.staged?(proxy_id) || current.stuck?(proxy_id)
      end

      def next
        if current.commit
          current.stored_data
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
