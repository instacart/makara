require 'makara2/version'
require 'makara2/railtie' if defined?(Rails)
module Makara2
  
  autoload :Cache,              'makara2/cache'
  autoload :ConfigParser,       'makara2/config_parser'
  autoload :ConnectionWrapper,  'makara2/connection_wrapper'
  autoload :Context,            'makara2/context'
  autoload :ErrorHandler,       'makara2/error_handler'
  autoload :Middleware,         'makara2/middleware'
  autoload :Pool,               'makara2/pool'

  module ConnectionProxy
    autoload :Base,             'makara2/connection_proxy/base'
    autoload :Mysql2,           'makara2/connection_proxy/mysql2'
  end

  module Errors
    autoload :AllConnectionsBlacklisted,  'makara2/errors/all_connections_blacklisted'
    autoload :BlacklistConnection,        'makara2/errors/blacklist_connection'
  end

  module Logging
    autoload :Subscriber, 'makara2/logging/subscriber'
  end

end
