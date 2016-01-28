require 'digest/md5'

# Keeps track of the current and previous context (hexdigests)
# If a new context is needed it can be generated via Makara::Context.generate

module Makara
  class Context
    class << self

      # This is the Thread variable that will hold until when we have to read from master for this user
      def stick_to_master_until
        Thread.current[:makara_stick_to_master_until]
      end

      def stick_to_master_until=(time)
        Thread.current[:makara_stick_to_master_until] = time
      end

      def clear_stick_to_master_until
        self.stick_to_master_until = nil
      end

      def generate(seed = nil)
        seed ||= "#{Time.now.to_i}#{Thread.current.object_id}#{rand(99999)}"
        Digest::MD5.hexdigest(seed)
      end

      def get_previous
        get_current_thread_local_for(:makara_context_previous)
      end

      def set_previous(context)
        set_current_thread_local(:makara_context_previous,context)
      end

      def get_current
        get_current_thread_local_for(:makara_context_current)
      end

      def set_current(context)
        set_current_thread_local(:makara_context_current,context)
      end

      protected

      def get_current_thread_local_for(type)
        t = Thread.current
        current = t.respond_to?(:thread_variable_get) ? t.thread_variable_get(type) : t[type]
        current ||= set_current_thread_local(type,generate)
      end

      def set_current_thread_local(type,context)
        t = Thread.current
        t.respond_to?(:thread_variable_set) ? t.thread_variable_set(type,context) : t[type]=context
      end

    end
  end
end
