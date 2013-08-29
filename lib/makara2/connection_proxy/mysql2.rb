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


      def query_options
        @query_options
      end


      def query(sql)
        if needed_by_all?(sql)
          @master_pool.send_to_all :query, sql
          @slave_pool.send_to_all :query, sql
        else
          appropriate_connection(sql) do |con|
            con.query(sql)
          end
        end
      end

      def affected_rows
        @master_pool.provide{|con| con.affected_rows }
      end

      def last_id
        @master_pool.provide{|con| con.last_id }
      end

      def connect
        @master_pool.send_to_all :connect
        @slave_pool.send_to_all :connect
      end

      def close
        @master_pool.send_to_all :close
        @slave_pool.send_to_all :close
      end
                    

      protected


      def connection_for(config)
        ::Mysql2::Client.new(config)
      end


    end
  end
end