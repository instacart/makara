module Makara
  class StateCache

    class << self

      def for(request, response)
        klass = state_cache_class

        unless connected_to?(klass)
          state_cache_config = Makara.primary_config[:state_cache]
          klass.connect(state_cache_config) unless state_cache_config.blank?
          track_connection(klass)
        end

        klass.new(request, response)
      end

      protected

      def state_cache_class
        key_or_class_name = Makara.primary_config[:state_cache_store] || :cookie

        case key_or_class_name
        when Symbol
          "::Makara::StateCaches::#{key_or_class_name.to_s.camelize}".constantize
        else
          key_or_class_name.to_s.constantize
        end
      end

      def connected_to?(state_cache_class)
        !!(@connected_state_cache || {})[state_cache_class.name]
      end

      def track_connection(state_cache_class)
        @connected_state_cache ||= {}
        @connected_state_cache[state_cache_class.name] = true
      end

    end

  end
end