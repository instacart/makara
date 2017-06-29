require 'digest/md5'

# Keeps track of the current and previous context (hexdigests)
# If a new context is needed it can be generated via Makara::Context.generate

module Makara
  class Context
    class << self

      def generate(seed = nil)
        seed ||= "#{Time.now.to_i}#{Thread.current.object_id}#{rand(99999)}"
        Digest::MD5.hexdigest(seed)
      end

      def get_previous
        fetch(:makara_context_previous) { generate }
      end

      def set_previous(context)
        previously_sticky.clear
        set(:makara_context_previous,context)
      end

      def get_current
        fetch(:makara_context_current) { generate }
      end

      def set_current(context)
        set(:makara_context_current,context)
      end

      def previously_stuck?(config_id)
        previously_sticky.fetch(config_id) do
          stuck?(Makara::Context.get_previous, config_id)
        end
      end

      # Called by `Proxy#stick_to_master!` to stick subsequent requests to
      # master. They'll see the current context as their previous context
      # when they're asking whether they should be stuck to master.
      def stick(context, config_id, ttl)
        Makara::Cache.write(cache_key_for(context, config_id), '1', ttl)
      end

      def stuck?(context, config_id)
        !!Makara::Cache.read(cache_key_for(context, config_id))
      end

      protected

      def previously_sticky
        fetch(:makara_previously_sticky) { Hash.new }
      end

      def cache_key_for(context, config_id)
        "makara::#{context}-#{config_id}"
      end

      def fetch(key)
        get(key) || set(key,yield)
      end

      if Thread.current.respond_to?(:thread_variable_get)
        def get(key)
          Thread.current.thread_variable_get(key)
        end

        def set(key,value)
          Thread.current.thread_variable_set(key,value)
        end
      else
        def get(key)
          Thread.current[key]
        end

        def set(key,value)
          Thread.current[key]=value
        end
      end

    end
  end
end
