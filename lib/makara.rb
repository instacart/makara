require 'makara/version'
require 'makara/railtie' if defined?(Rails)
module Makara

  autoload :Cache,              'makara/cache'
  autoload :ConfigParser,       'makara/config_parser'
  autoload :ConnectionWrapper,  'makara/connection_wrapper'
  autoload :Context,            'makara/context'
  autoload :ErrorHandler,       'makara/error_handler'
  autoload :Middleware,         'makara/middleware'
  autoload :Pool,               'makara/pool'
  autoload :Proxy,              'makara/proxy'

  module Errors
    autoload :AllConnectionsBlacklisted,  'makara/errors/all_connections_blacklisted'
    autoload :BlacklistConnection,        'makara/errors/blacklist_connection'
    autoload :InitialConnectionFailure,   'makara/errors/initial_connection_failure'
    autoload :NoConnectionsAvailable,     'makara/errors/no_connections_available'
  end

  module Logging
    autoload :Subscriber, 'makara/logging/subscriber'
  end

end
