require 'active_support/core_ext/hash/keys'

module Makara2
  class Proxy < ::SimpleDelegator

    class_attribute :hijack_methods
    self.hijack_methods = []

    class << self
      def hijack_method(*method_names)
        self.hijack_methods = self.hijack_methods || []
        self.hijack_methods |= method_names

        method_names.each do |method_name|
          define_method method_name do |*args|
            appropriate_connection(*args) do |con|
              con.send(method_name, *args)
            end
          end
        end
      end

      def send_to_all(*method_names)
        method_names.each do |method_name|
          define_method method_name do |*args|
            send_to_all method_name, *args
          end
        end
      end
    end


    attr_reader :error_handler

    def initialize(config)
      @config         = config.symbolize_keys
      @config_parser  = Makara2::ConfigParser.new(@config)
      @id             = @config_parser.id
      @ttl            = @config_parser.makara_config[:master_ttl]
      @hijacked       = false
      @error_handler  ||= ::Makara2::ErrorHandler.new
      instantiate_connections
    end

    def __getobj__
      @master_pool.try(:any) || @slave_pool.try(:any) || super
    end


    def current_pool_name
      pool, name = @master_context == Makara2::Context.get_current ? [@master_pool, 'Master'] : [@slave_pool, 'Slave']
      connection_name = pool.current_connection_name
      name << "/#{connection_name}" if connection_name
      name
    end


    def hijacked?
      @hijacked
    end


    protected


    def send_to_all(method_name, *args)
      @master_pool.send_to_all method_name, *args
      @slave_pool.send_to_all method_name, *args
    end


    def appropriate_connection(*args)
      appropriate_pool(*args) do |pool|
        pool.provide do |connection|
          hijacked do
            yield connection
          end
        end
      end
    end

    def appropriate_pool(*args)

      # the args provided absolutely need master
      if needs_master?(args)
        stick_to_master(args)
        yield @master_pool

      # in this context, we've already stuck to master
      elsif Makara2::Context.get_current == @master_context
        yield @master_pool

      # the previous context stuck us to master
      elsif previously_stuck_to_master?
        stick_to_master(args, false)
        yield @master_pool

      # all slaves are down
      elsif @slave_pool.completely_blacklisted?
        stick_to_master(args)
        yield @master_pool

      # yay! use a slave
      else
        yield @slave_pool
      end

    end


    # do these args require a master connection
    def needs_master?(*args)
      true
    end


    def hijacked
      @hijacked = true
      yield
    ensure
      @hijacked = false
    end


    def previously_stuck_to_master?
      !!Makara2::Cache.read("makara2::#{Makara2::Context.get_previous}-#{@id}")
    end


    def stick_to_master(args, write_to_cache = true)
      return unless should_stick?(args)
      return if @master_context == Makara2::Context.get_current
      @master_context = Makara2::Context.get_current
      Makara2::Cache.write("makara2::#{@master_context}-#{@id}", '1', @ttl) if write_to_cache
    end


    def should_stick?(args)
      true
    end


    def instantiate_connections
      @master_pool = Makara2::Pool.new(self)
      @config_parser.master_configs.each do |master_config|
        @master_pool.add connection_for(master_config), master_config
      end

      @slave_pool = Makara2::Pool.new(self)
      @config_parser.slave_configs.each do |slave_config|
        @slave_pool.add connection_for(slave_config), slave_config
      end
    end


    def connection_for(config)
      raise NotImplementedError
    end

  end
end