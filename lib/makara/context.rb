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
        @previous_context ||= generate
      end


      def set_previous(context)
        @previous_context = context
      end


      def get_current
        @current_context ||= generate
      end


      def set_current(context)
        @current_context = context
      end

    end
  end
end
