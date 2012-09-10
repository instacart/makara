module Makara
  
  module Connection
    # module which gets extended on adapter instances
    # provides a way to reference the connection list
    # overrides execute so it will delegate to the connection list once
    module Decorator

      # set the connection list
      def makara_adapter=(adapter)
        @makara_adapter = adapter
      end

      # if we have a connection list and we're not alrady hijacked,
      # allow the connection list to handle the execute
      def with_makara
        if @makara_adapter && !@makara_adapter.hijacking_execute?
          yield @makara_adapter
        else
          yield nil
        end
      end

      # execute the sql statement, give precedence to the 
      def execute(sql, name = nil)
        with_makara do |acceptor|
          # ternary needed for testing purposes (stubbing issue)
          return (defined?(super) ? super(sql, name) : nil) if acceptor.nil?
          acceptor.execute(sql, name)
        end
      end
    end
  end
end