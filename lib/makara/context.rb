require 'digest/md5'
require 'active_support/notifications'

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
        get_current_thread_local_for(:makara_context_previous).tap do |context|
          ActiveSupport::Notifications.instrument('makara.context.get_previous', context: context)
        end
      end

      def set_previous(context)
        ActiveSupport::Notifications.instrument('makara.context.set_previous', context: context)
        set_current_thread_local(:makara_context_previous, context)
      end

      def get_current
        get_current_thread_local_for(:makara_context_current).tap do |context|
          ActiveSupport::Notifications.instrument('makara.context.get_current', context: context)
        end
      end

      def set_current(context)
        ActiveSupport::Notifications.instrument('makara.context.set_current', context: context)
        set_current_thread_local(:makara_context_current, context)
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
