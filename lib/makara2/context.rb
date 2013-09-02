require 'digest/md5'

module Makara2
  class Context
    class << self


      def generate(seed = nil)
        seed ||= "#{Time.now.to_i}#{Thread.current.object_id}#{rand(99999)}"
        Digest::MD5.hexdigest(seed)
      end


      def get_previous
        @previous_context || 'default_previous'
      end


      def set_previous(context)
        @previous_context = context
      end


      def get_current
        @current_context || 'default_current'
      end


      def set_current(context)
        @current_context = context
      end

    end
  end
end