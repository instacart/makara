module Makara2
  module ConnectionProxy
    class Mysql2 < Makara2::ConnectionProxy::Base

      class QueryOptionProxy

        def initialize(master_pool, slave_pool)
          @master_pool = master_pool
          @slave_pool  = slave_pool
        end

        def method_missing(method_name, *args, &block)
          @master_pool.each_connection do |connection|
            connection.query_options.send(method_name, *args, &block)
          end

          @slave_pool.each_connection do |connection|
            connection.query_options.send(method_name, *args, &block)
          end
        end
      end


      invoke_on_appropriate_connection :query
      invoke_on_master_connection :affected_rows, :last_id
      invoke_on_all_connections :connect, :close


      def initialize(*args)
        super
        @query_options = QueryOptionProxy.new(@master_pool, @slave_pool)
      end


      def query_options
        @query_options
      end


      protected


      def connection_for(config)
        ::Mysql2::Client.new(config)
      end


    end
  end
end