module Makara
  module Logging

    module Subscriber

      def sql(event)
        name = event.payload[:name]
        name = [current_wrapper_name(event), name].compact.join(' ')
        event.payload[:name] = name
        super(event)
      end

      protected

      def current_wrapper_name(event)
        connection_object_id = event.payload[:connection_id]
        return nil unless connection_object_id

        underlying_adapter = ObjectSpace._id2ref(connection_object_id)

        return nil unless underlying_adapter
        return nil unless underlying_adapter.respond_to?(:makara_adapter)

        adapter = underlying_adapter.makara_adapter
        return nil unless adapter.respond_to?(:current_wrapper)

        name = adapter.name
        wrapper_name = adapter.current_wrapper.try(:name)
        return "[#{name}]" unless wrapper_name

        "[#{name}/#{wrapper_name}]"
      end
    end

  end
end