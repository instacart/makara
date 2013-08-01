require 'makara/railtie' if defined?(Rails)

module Makara

  autoload :ConfigParser,   'makara/config_parser'
  autoload :Middleware,     'makara/middleware'
  autoload :StateCache,     'makara/state_cache'
  autoload :VERSION,        'makara/version'

  module Connection
    autoload :Decorator,    'makara/connection/decorator'
    autoload :ErrorHandler, 'makara/connection/error_handler'
    autoload :Group,        'makara/connection/group'
    autoload :Wrapper,      'makara/connection/wrapper'
  end

  module Logging
    autoload :Subscriber,   'makara/logging/subscriber'
  end

  module StateCaches
    autoload :Abstract,     'makara/state_caches/abstract'
    autoload :Cookie,       'makara/state_caches/cookie'
    autoload :Rails,        'makara/state_caches/rails'
    autoload :Redis,        'makara/state_caches/redis'
  end

  class << self

    def namespace
      primary_config[:namespace]
    end

    def reset!
      @adapters = []
      @primary_config = nil
    end

    def register_adapter(adapter)
      @adapters ||= []
      raise "[Makara] all adapters must be given a unique id. \"#{adapter.id}\" has already been used." if @adapters.map(&:id).include?(adapter.id)
      @adapters << adapter
      @adapters = @adapters.sort_by(&:id)
    end

    def unregister_adapter(adapter)
      @adapters ||= []
      @adapters.delete(adapter)
    end

    def force_master!
      to_all(:force_master!)
    end

    def with_master(connection_indexes = nil)
      previous_values = {}
      adapters.each do |adapter|
        previous_values[adapter.id] = adapter.forced_to_master?
      end

      if connection_indexes
        connection_indexes.each do |index|
          adapters[index].force_master!
        end
      else
        force_master!
      end

      yield

    ensure

      adapters.each do |adapter|
        unless previous_values[adapter.id]
          adapter.release_master!
        end
      end
    end

    def to_all(method_sym)
      adapters.each(&method_sym)
    end

    def adapters
      @adapters || []
    end

    def in_use?
      adapters.any?
    end

    def multi?
      adapters.size > 1
    end

    def indexes_currently_using_master
      indexes = []
      adapters.each_with_index{|con, i| indexes << i if con.currently_master? }
      indexes
    end

    def primary_config
      @primary_config ||= begin
        # active_record 3.1+
        ActiveRecord::Base.connection.pool.spec.config
      rescue
        begin
          # active_record 3.0.x
          ActiveRecord::Base.connection_handler.connection_pools['ActiveRecord::Base'].spec.config
        rescue
          {}
        end
      end
    end
  end
end

require 'active_record/connection_adapters/makara_adapter'