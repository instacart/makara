module Makara
  module ConnectionWrapper

    # module which gets extended on adapter instances
    # provides a way to reference the connection list
    # overrides execute so it will delegate to the connection list once
    module ConnectionDecorator

      # set the connection list
      def connection_list=(cl)
        @connection_list = cl
      end

      # if we have a connection list and we're not alrady hijacked,
      # allow the connection list to handle the execute
      def with_makara
        if @connection_list && !@connection_list.hijacking_execute?
          yield @connection_list
        else
          yield nil
        end
      end

      # execute the sql statement, give precedence to the 
      def execute(sql, name = nil)
        with_makara do |acceptor|
          return super(sql, name) if acceptor.nil?
          acceptor.execute(sql, name)
        end
      end

    end

  end
end