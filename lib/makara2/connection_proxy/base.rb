module Makara2
  module ConnectionProxy
    class Base

      SQL_SLAVE_KEYWORDS      = ['select', 'show tables', 'show fields', 'describe', 'show database', 'show schema', 'show view', 'show index']
      SQL_SLAVE_MATCHER       = /^(#{SQL_SLAVE_KEYWORDS.join('|')})/i

      DEFAULT_CONFIG = {
        blacklist_duration: 30
      }

      def initialize(config)
        @config         = DEFAULT_CONFIG.merge(config)
        @config_parser  = Makara2::ConfigParser.new(@config)
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


      def appropriate_pool(sql = nil)

        if Makara2::Context.get == @master_context
          yield @master_pool
        else
          if needs_master?(sql) || @slave_pool.completely_blacklisted?
            yield stick_to_master(sql, @master_pool)
          else
            yield @slave_pool
          end
        end
      end


      def needs_master?(sql)
        return false if sql.to_s =~ SQL_SLAVE_MATCHER
        true
      end


      def stick_to_master(sql, pool)

        if should_stick?(sql)
          @master_context = Makara2::Context.get
        end

        pool
      end


      def should_stick?(sql)
        return false if sql.to_s =~ /^show ([\w]+ )?tables?/i
        return false if sql.to_s =~ /^show (full )?fields?/i
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