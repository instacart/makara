module Makara2
  module ConnectionProxy
    class Base

      SQL_SLAVE_KEYWORDS      = ['select', 'show tables', 'show fields', 'describe', 'show database', 'show schema', 'show view', 'show index']
      SQL_SLAVE_MATCHER       = /^(#{SQL_SLAVE_KEYWORDS.join('|')})/i

      DEFAULT_CONFIG = {
        blacklist_duration: 30,
        sticky_slave: true,
        sticky_mater: true,
      }

      def initialize(config)
        @config = DEFAULT_CONFIG.merge(config)
        @config_parser = Makara2::ConfigParser.new(@config)
        instantiate_connections
      end


      def query(sql)
        appropriate_pool(sql) do |pool|
          pool.provide do |connection|
            connection.query(sql)
          end
        end
      end


      def method_missing(method_name, *args, &block)
        @master_pool.any do |connection|
          connection.send(method_name, *args, &block)
        end
      end


      def respond_to_missing?(method_name, include_private = false)
        @master_pool.any do |connection|
          return true if connection.respond_to?(method_name, include_private)
        end
        super
      end


      protected


      def appropriate_pool(sql)
        if needs_master?(sql)
          puts "Using master: #{sql}"
          yield @master_pool
        else
          puts "Using slave: #{sql}"
          unless @slave_pool.empty?
            yield @slave_pool
          else
            yield @master_pool
          end
        end
      end


      def needs_master?(sql)
        return false if sql.to_s =~ SQL_SLAVE_MATCHER
        true
      end


      def instantiate_connections
        @master_pool = Makara2::Pool.new(@config)
        @config_parser.master_configs.each do |master_config|
          @master_pool << connection_for(master_config)
        end

        @slave_pool = Makara2::Pool.new(@config)
        @config_parser.slave_configs.each do |slave_config|
          @slave_pool << connection_for(slave_config)
        end
      end


      def connection_for(config)
        raise NotImplementedError
      end

    end
  end
end