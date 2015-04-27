require 'delegate'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/hash/keys'

# The entry point of Makara. It contains a master and slave pool which are chosen based on the invocation
# being proxied. Makara::Proxy implementations should declare which methods they are hijacking via the
# `hijack_method` class method.

module Makara
  class Proxy < ::SimpleDelegator

    class_attribute :hijack_methods
    self.hijack_methods = []

    class << self
      def hijack_method(*method_names)
        self.hijack_methods = self.hijack_methods || []
        self.hijack_methods |= method_names

        method_names.each do |method_name|
          define_method method_name do |*args|
            appropriate_connection(method_name, args) do |con|
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
    attr_reader :sticky

    def initialize(config)
      @config         = config.symbolize_keys
      @config_parser  = Makara::ConfigParser.new(@config)
      @id             = @config_parser.id
      @ttl            = @config_parser.makara_config[:master_ttl]
      @sticky         = @config_parser.makara_config[:sticky]
      @hijacked       = false
      @error_handler  ||= ::Makara::ErrorHandler.new
      @skip_sticking  = false
      instantiate_connections
    end

    def without_sticking
      @skip_sticking = true
      yield
    ensure
      @skip_sticking = false
    end

    def hijacked?
      @hijacked
    end

    def stick_to_master!(write_to_cache = true)
      @master_context = Makara::Context.get_current
      Makara::Cache.write("makara::#{@master_context}-#{@id}", '1', @ttl) if write_to_cache
    end

    def method_missing(m, *args, &block)
      target = @master_pool.any

      begin
        target.respond_to?(m, true) ? target.__send__(m, *args, &block) : super(m, *args, &block)
      ensure
        $@.delete_if {|t| %r"\A#{Regexp.quote(__FILE__)}:#{__LINE__-2}:"o =~ t} if $@
      end
    end

    class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
      def respond_to#{RUBY_VERSION.to_s =~ /^1.8/ ? nil : '_missing'}?(m, include_private = false)
        @master_pool.any.__getobj__.respond_to?(m, true)
      end
    RUBY_EVAL

    protected


    def send_to_all(method_name, *args)
      # slave pool must run first to allow for slave-->master failover without running operations on master twice.
      @slave_pool.send_to_all method_name, *args
      @master_pool.send_to_all method_name, *args
    end


    # based on the method_name and args, provide the appropriate connection
    # mark this proxy as hijacked so the underlying connection does not attempt to check
    # with back with this proxy.
    def appropriate_connection(method_name, args)
      appropriate_pool(method_name, args) do |pool|
        pool.provide do |connection|
          hijacked do
            yield connection
          end
        end
      end
    end


    # master or slave
    def appropriate_pool(method_name, args)

      # for testing purposes
      pool = _appropriate_pool(method_name, args)

      yield pool

    rescue ::Makara::Errors::AllConnectionsBlacklisted, ::Makara::Errors::NoConnectionsAvailable => e
      if pool == @master_pool
        @master_pool.connections.each(&:_makara_whitelist!)
        @slave_pool.connections.each(&:_makara_whitelist!)
        raise e
      else
        @master_pool.blacklist_errors << e
        retry
      end
    end

    def _appropriate_pool(method_name, args)
      # the args provided absolutely need master
      if needs_master?(method_name, args)
        stick_to_master(method_name, args)
        @master_pool

      # in this context, we've already stuck to master
      elsif Makara::Context.get_current == @master_context
        @master_pool

      # the previous context stuck us to master
      elsif previously_stuck_to_master?

        # we're only on master because of the previous context so
        # behave like we're sticking to master but store the current context
        stick_to_master(method_name, args, false)
        @master_pool

      # all slaves are down (or empty)
      elsif @slave_pool.completely_blacklisted?
        stick_to_master(method_name, args)
        @master_pool

      # yay! use a slave
      else
        @slave_pool
      end
    end

    # do these args require a master connection
    def needs_master?(method_name, args)
      true
    end


    def hijacked
      @hijacked = true
      yield
    ensure
      @hijacked = false
    end


    def previously_stuck_to_master?
      return false unless @sticky
      !!Makara::Cache.read("makara::#{Makara::Context.get_previous}-#{@id}")
    end


    def stick_to_master(method_name, args, write_to_cache = true)
      # if we're already stuck to master, don't bother doing it again
      return if @master_context == Makara::Context.get_current

      # check to see if we're configured, bypassed, or some custom implementation has input
      return unless should_stick?(method_name, args)

      # do the sticking
      stick_to_master!(write_to_cache)
    end


    # if we are configured to be sticky and we aren't bypassing stickiness
    def should_stick?(method_name, args)
      @sticky && !@skip_sticking
    end


    # use the config parser to generate a master and slave pool
    def instantiate_connections
      @master_pool = Makara::Pool.new('master', self)
      @config_parser.master_configs.each do |master_config|
        @master_pool.add master_config.merge(@config_parser.makara_config) do
          connection_for(master_config)
        end
      end

      @slave_pool = Makara::Pool.new('slave', self)
      @config_parser.slave_configs.each do |slave_config|
        @slave_pool.add slave_config.merge(@config_parser.makara_config) do
          connection_for(slave_config)
        end
      end
    end


    def connection_for(config)
      raise NotImplementedError
    end

  end
end
