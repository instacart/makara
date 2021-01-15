require 'active_support'
require 'makara/version'
require 'makara/railtie' if defined?(Rails)
module Makara
  autoload :Cache,              'makara/cache'
  autoload :ConfigParser,       'makara/config_parser'
  autoload :ConnectionWrapper,  'makara/connection_wrapper'
  autoload :Context,            'makara/context'
  autoload :Cookie,             'makara/cookie'
  autoload :ErrorHandler,       'makara/error_handler'
  autoload :Middleware,         'makara/middleware'
  autoload :Pool,               'makara/pool'
  autoload :Proxy,              'makara/proxy'

  module Errors
    autoload :MakaraError,                   'makara/errors/makara_error'
    autoload :AllConnectionsBlacklisted,     'makara/errors/all_connections_blacklisted'
    autoload :BlacklistConnection,           'makara/errors/blacklist_connection'
    autoload :NoConnectionsAvailable,        'makara/errors/no_connections_available'
    autoload :BlacklistedWhileInTransaction, 'makara/errors/blacklisted_while_in_transaction'
    autoload :InvalidShard,                  'makara/errors/invalid_shard'
  end

  module Logging
    autoload :Logger,     'makara/logging/logger'
    autoload :Subscriber, 'makara/logging/subscriber'
  end

  module Strategies
    autoload :Abstract,         'makara/strategies/abstract'
    autoload :RoundRobin,       'makara/strategies/round_robin'
    autoload :PriorityFailover, 'makara/strategies/priority_failover'
    autoload :ShardAware,       'makara/strategies/shard_aware'
  end

end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::LogSubscriber.log_subscribers.each do |subscriber|
    subscriber.extend ::Makara::Logging::Subscriber
  end
end
