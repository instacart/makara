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
        get_current_thread_local_context_for(:makara_context_previous)
      end

      def set_previous(context)
        set_current_thread_local(:makara_cached_previous,nil)
        set_current_thread_local(:makara_context_previous,context)
      end

      def get_current
        get_current_thread_local_context_for(:makara_context_current)
      end

      def set_current(context)
        set_current_thread_local(:makara_context_current,context)
      end

      # cache the current context so that it can be checked as the "previous" context by a subsequent request.
      # this is done when the current context gets stuck to master.
      # the current context is sent with the response as a cookie - any subsequent request will send the cookie (until it expires);
      # if the context from the cookie is found in the cache, it means the previous request was stuck to maaster
      def cache_current(config_id, ttl)
        Makara::Cache.write("makara::#{get_current}-#{config_id}", '1', ttl)
      end

      def cached_previous?(config_id)
        cached_previous = get_current_thread_local_for(:makara_cached_previous)
        # if haven't memoized the result of the Cache.read yet
        if cached_previous.nil?
          cached_previous = !!Makara::Cache.read("makara::#{Makara::Context.get_previous}-#{config_id}")
          set_current_thread_local(:makara_cached_previous,cached_previous)
        end
        cached_previous
      end

      protected

      def get_current_thread_local_for(type)
        t = Thread.current
        t.respond_to?(:thread_variable_get) ? t.thread_variable_get(type) : t[type]
      end

      def get_current_thread_local_context_for(type)
        current = get_current_thread_local_for(type)
        current ||= set_current_thread_local(type,generate)
      end

      def set_current_thread_local(type,context)
        t = Thread.current
        t.respond_to?(:thread_variable_set) ? t.thread_variable_set(type,context) : t[type]=context
      end

    end
  end
end
