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

      # grabs the wrapper used in this event via it's object_id
      # uses the wrapper's makara adapter to modify the name of the event
      # the name of the used connection will be prepended to the sql log
      ###
      ### [adapter_id/wrapper_name] User Load (1.3ms) SELECT * FROM `users`;
      ###
      def current_wrapper_name(event)
        connection_object_id = event.payload[:connection_id]
        return nil unless connection_object_id

        underlying_adapter = ObjectSpace._id2ref(connection_object_id)

        return nil unless underlying_adapter
        return nil unless underlying_adapter.respond_to?(:makara_adapter)

        adapter = underlying_adapter.makara_adapter
        return nil unless adapter.respond_to?(:current_wrapper)

        id = adapter.id
        wrapper_name = adapter.current_wrapper.try(:name)
        return "[#{id}]" unless wrapper_name

        if id == 'default' && !Makara.multi?
          "[#{wrapper_name}]"
        else
          "[#{id}/#{wrapper_name}]"
        end
      end
    end

  end
end