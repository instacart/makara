module Makara
  module ConnectionWrapper

    module ConnectionDecorator

      def connection_list=(cl)
        @connection_list = cl
      end

      def with_makara
        if @connection_list && !@connection_list.hijacking_execute?
          yield @connection_list
        else
          yield nil
        end
      end

      def execute(sql, name = nil)
        with_makara do |acceptor|
          return super(sql, name) if acceptor.nil?
          acceptor.execute(sql, name)
        end
      end

    end

  end
end