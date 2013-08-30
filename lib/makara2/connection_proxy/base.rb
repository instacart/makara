module Makara2
  module ConnectionProxy
    class Base < ::SimpleDelegator


      class << self

        def invoke_on_appropriate_connection(*method_names)
          method_names.each do |method_name|
            define_method method_name do |sql|
              invoke_on_appropriate_connection method_name, sql
            end
          end

        end

        def invoke_on_master_connection(*method_names)
          method_names.each do |method_name|
            define_method method_name do
              invoke_on_master_connection method_name
            end
          end
        end

        def invoke_on_all_connections(*method_names)
          method_names.each do |method_name|
            define_method method_name do |*args|
              @master_pool.send_to_all method_name, *args
              @slave_pool.send_to_all method_name, *args
            end
          end
        end

      end


      SQL_SLAVE_MATCHER       = /^select\s/i
      SQL_ALL_MATCHER         = /^set\s/i

      DEFAULT_CONFIG = {
        master_ttl: 5,
        blacklist_duration: 30
      }

      def initialize(config)
        @config         = DEFAULT_CONFIG.merge(config)
        @config_parser  = Makara2::ConfigParser.new(@config)
        @id             = @config_parser.id
        @ttl            = @config_parser.ttl
        instantiate_connections
      end

      def __getobj__
        @master_pool.try(:any) || @slave_pool.try(:any) || super
      end

      def current_pool_name
        pool = @current_pool || @slave_pool
        name = pool == @master_pool ? 'Master' : 'Slave'
        connection_name = pool.current_connection_name
        name << "/#{connection_name}" if connection_name
        name
      end

      protected


      def invoke_on_appropriate_connection(method, sql)
        if needed_by_all?(sql)
          @master_pool.send_to_all method, sql
          @slave_pool.send_to_all method, sql
        else
          appropriate_pool(sql) do |pool|
            @current_pool = pool
            pool.provide do |connection|
              connection.send(method, sql)
            end
          end
        end
      end


      def invoke_on_master_connection(method_name)
        stick_to_master(nil)
        @master_pool.provide do |con|
          con.send(method_name)
        end
      end


      def appropriate_pool(sql = nil)

        # the sql provided absolutely needs master
        if needs_master?(sql)
          stick_to_master(sql)
          yield @master_pool

        # in this context, we've already stuck to master
        elsif Makara2::Context.get_current == @master_context
          yield @master_pool

        # the previous context stuck us to master
        elsif previously_stuck_to_master?
          stick_to_master(sql, false)
          yield @master_pool

        # all slaves are down
        elsif @slave_pool.completely_blacklisted?
          stick_to_master(sql)
          yield @master_pool

        # yay! use a slave
        else
          yield @slave_pool
        end

      end


      # does this sql require a master connection
      def needs_master?(sql)
        return false if sql.to_s =~ SQL_SLAVE_MATCHER
        true
      end


      def needed_by_all?(sql)
        return true if sql.to_s =~ SQL_ALL_MATCHER
        false
      end


      def previously_stuck_to_master?
        !!Makara2::Cache.read("makara2::#{Makara2::Context.get_previous}-#{@id}")
      end


      def stick_to_master(sql, write_to_cache = true)
        return unless should_stick?(sql)
        @master_context = Makara2::Context.get_current    
        Makara2::Cache.write("makara2::#{@master_context}-#{@id}", '1', @ttl) if write_to_cache
      end


      def should_stick?(sql)
        return true if sql.nil?
        return false if sql.to_s =~ /^show\s([\w]+\s)?(field|table|database|schema|view|index)(es|s)?/i
        return false if sql.to_s =~ /^(set|describe|explain|pragma)\s/i
        true
      end


      def instantiate_connections
        @master_pool = Makara2::Pool.new(@config)
        @config_parser.master_configs.each do |master_config|
          @master_pool.add connection_for(master_config), master_config
        end

        @slave_pool = Makara2::Pool.new(@config)
        @config_parser.slave_configs.each do |slave_config|
          @slave_pool.add connection_for(slave_config), slave_config
        end
      end


      def connection_for(config)
        raise NotImplementedError
      end

    end
  end
end