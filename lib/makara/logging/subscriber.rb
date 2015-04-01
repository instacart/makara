module Makara
  module Logging

    module Subscriber
      IGNORE_PAYLOAD_NAMES = ["SCHEMA", "EXPLAIN"]

      def sql(event)
        name = event.payload[:name]
        unless IGNORE_PAYLOAD_NAMES.include?(name)
          name = [current_wrapper_name(event), name].compact.join(' ')
          event.payload[:name] = name
        end
        super(event)
      end

      protected

      # grabs the adapter used in this event via it's object_id
      # uses the adapter's connection proxy to modify the name of the event
      # the name of the used connection will be prepended to the sql log
      ###
      ### [Master|Slave] User Load (1.3ms) SELECT * FROM `users`;
      ###
      def current_wrapper_name(event)
        connection_object_id = event.payload[:connection_id]
        return nil unless connection_object_id

        adapter = ObjectSpace._id2ref(connection_object_id)

        return nil unless adapter
        return nil unless adapter.respond_to?(:_makara_name)

        "[#{adapter._makara_name}]"
      end
    end

  end
end
