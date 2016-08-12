require 'active_support/core_ext/object/try'
require 'active_support/notifications'

# The Makara Cache should have access to your centralized cache store.
# It serves the purpose of storing the Makara::Context across requests, servers, etc.

module Makara
  module Cache

    autoload :MemoryStore, 'makara/cache/memory_store'
    autoload :NoopStore,   'makara/cache/noop_store'

    class << self

      def store=(store)
        @store = store
      end

      def read(key)
        ActiveSupport::Notifications.instrument('makara.cache.read', { key: key })
        store.try(:read, key)
      end

      def write(key, value, ttl)
        payload = { key: key, value: value, ttl: ttl.to_i }
        ActiveSupport::Notifications.instrument('makara.cache.write', payload)
        store.try(:write, key, value, :expires_in => ttl.to_i)
      end

      protected

      def store
        case @store
        when :noop, :null
          @store = Makara::Cache::NoopStore.new
        when :memory
          @store = Makara::Cache::MemoryStore.new
        else
          if defined?(Rails)

            # in AR3 RAILS_CACHE may not be loaded if the full env is not present
            # Rails.cache will throw an error because of it.
            if ActiveRecord::VERSION::MAJOR < 4
              @store ||= Rails.cache if defined?(RAILS_CACHE)
            else
              @store ||= Rails.cache if defined?(Rails)
            end
          end
        end

        @store
      end

    end

  end
end
