require 'active_support/core_ext/object/try'

# The Makara2 Cache should have access to your centralized cache store.
# It serves the purpose of storing the Makara2::Context across requests, servers, etc.

module Makara2
  module Cache

    autoload :MemoryStore, 'makara2/cache/memory_store'
    autoload :NoopStore,   'makara2/cache/noop_store'

    class << self

      def store=(store)
        @store = store
      end

      def read(key)
        store.try(:read, key)
      end

      def write(key, value, ttl)
        store.try(:write, key, value, :expires_in => ttl.to_i)
      end

      protected

      def store
        case @store
        when :noop, :null
          @store = Makara2::Cache::NoopStore.new
        when :memory
          @store = Makara2::Cache::MemoryStore.new
        else
          @store ||= Rails.cache if defined?(Rails)
        end

        @store
      end

    end

  end
end