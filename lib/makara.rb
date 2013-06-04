require 'makara/railtie' if defined?(Rails)

module Makara

  autoload :ConfigParser,   'makara/config_parser'
  autoload :Middleware,     'makara/middleware'
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

  module StateCache
    autoload :Access,       'makara/state_cache/access'
    autoload :Abstract,     'makara/state_cache/abstract'
    autoload :Cookie,       'makara/state_cache/cookie'
    autoload :Rails,        'makara/state_cache/rails'
    autoload :Redis,        'makara/state_cache/redis'
  end

  class << self


    def state_cache(request, response)
      klass = state_cache_class

      unless @connected_state_cache
        state_cache_config = primary_config[:state_cache]
        klass.connect(state_cache_config) unless state_cache_config.blank?
        @connected_state_cache = true
      end

      klass.new(request, response)
    end

    def namespace
      primary_config[:namespace]
    end

    def reset!
      @adapters = []
    end

    def register_adapter(adapter)
      @adapters ||= []
      raise "[Makara] all adapters must be given a unique id. \"#{adapter.id}\" has already been used." if @adapters.map(&:id).include?(adapter.id)
      @adapters << adapter
      @adapters = @adapters.sort_by(&:id)
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

    protected

    def primary_config
      ActiveRecord::Base.connection.pool.spec.config
    rescue
      {}
    end


    def state_cache_class
      key_or_class_name = primary_config[:state_cache_store] || :cookie

      case key_or_class_name
      when Symbol
        "::Makara::StateCache::#{key_or_class_name.to_s.camelize}".constantize
      else
        key_or_class_name.to_s.constantize
      end
    end
  end
end

require 'active_record/connection_adapters/makara_adapter'