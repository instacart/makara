require 'makara/version'
require 'makara/railtie' if defined?(Rails)
require 'active_record'
require 'active_support/all'

module Makara

  autoload :Cache,              'makara/cache'
  autoload :ConfigParser,       'makara/config_parser'
  autoload :ConnectionWrapper,  'makara/connection_wrapper'
  autoload :Context,            'makara/context'
  autoload :ErrorHandler,       'makara/error_handler'
  autoload :Middleware,         'makara/middleware'
  autoload :SidekiqMiddleware,  'makara/sidekiq_middleware'
  autoload :Pool,               'makara/pool'
  autoload :Proxy,              'makara/proxy'

  module Errors
    autoload :AllConnectionsBlacklisted,  'makara/errors/all_connections_blacklisted'
    autoload :BlacklistConnection,        'makara/errors/blacklist_connection'
    autoload :NoConnectionsAvailable,     'makara/errors/no_connections_available'
  end

  module Logging
    autoload :Logger,     'makara/logging/logger'
    autoload :Subscriber, 'makara/logging/subscriber'
  end

  module Strategies
    autoload :Abstract,         'makara/strategies/abstract'
    autoload :RoundRobin,       'makara/strategies/round_robin'
    autoload :PriorityFailover, 'makara/strategies/priority_failover'
  end

  def self.without_sticking(&block)
    ActiveRecord::Base.connection.without_sticking(&block)
  end

  def self.force_slave(&block)
    ActiveRecord::Base.connection.force_slave(&block)
  end

  def self.force_master(&block)
    ActiveRecord::Base.connection.force_master(&block)
  end

  def self.stick_to_master!(write_to_cache: true, ttl: master_ttl)
    ActiveRecord::Base.connection.stick_to_master!(write_to_cache, ttl)
  end

  def self.master_ttl
    ActiveRecord::Base.connection.config[:master_ttl].to_i
  end
end
