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
      release_master!
      release_forced_ids!
      release_stuck_ids!
      @primary_config = nil
    end

    # force connections with this id to master
    def force_to_master!(id)
      @forced_to_master_ids ||= []
      @forced_to_master_ids |= [id.to_s]
    end

    def forced_to_master?(id)
      return true if @forced_to_master
      @forced_to_master_ids ||= []
      @forced_to_master_ids.include?(id.to_s)
    end

    def currently_forced_ids
      @forced_to_master_ids ||= []
    end

    def release_forced_ids!
      @forced_to_master_ids = []
    end

    # forces everyone to master all the time
    def force_master!
      @forced_to_master = true
    end

    # release the global enforcement
    def release_master!
      @forced_to_master = false
    end

    def stick_id!(id)
      @currently_stuck_ids ||= []
      @currently_stuck_ids |= [id.to_s]
    end

    def release_stuck_ids!
      @currently_stuck_ids = []
    end

    def currently_stuck_ids
      @currently_stuck_ids ||= []
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
