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

      def initialize(*args)
        super
        @query_options = QueryOptionProxy.new(@master_pool, @slave_pool)
      end

      def connect
        @master_pool.send_to_all :connect
        @slave_pool.send_to_all :connect
      end

      def close
        @master_pool.send_to_all :close
        @slave_pool.send_to_all :close
      end

      def query_options
        @query_options
      end

      def affected_rows
        appropriate_pool{|pool| pool.provide{|connection| connection.affected_rows }}
      end

      def last_id
        appropriate_pool{|pool| pool.provide{|connection| connection.last_id }}
      end

      protected

      def connection_for(config)
        ::Mysql2::Client.new(config)
      end

    end
  end
end