require 'active_support/core_ext/object/try'

module Makara2
  module Cache

    class MemoryStore

      def initialize
        @data = {}
      end

      def read(key)
        clean
        @data[key].try(:[], 0)
      end

      def write(key, value, options = {})
        clean
        @data[key] = [value, Time.now.to_i + (options[:expires_in] || 5).to_i]
        true
      end

      protected

      def clean
        @data.delete_if{|k,v| v[1] <= Time.now.to_i }
      end

    end

    class NoopStore
      def read(key)
        nil
      end

      def write(key, value, options = {})
        nil
      end
    end

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
        when :noop
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