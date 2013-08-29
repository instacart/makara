require "makara2/version"

module Makara2
  
  autoload :Cache,              'makara2/cache'
  autoload :ConfigParser,       'makara2/config_parser'
  autoload :ConnectionWrapper,  'makara2/connection_wrapper'
  autoload :Context,            'makara2/context'
  autoload :ErrorHandler,       'makara2/error_handler'
  autoload :Pool,               'makara2/pool'

  module ConnectionProxy
    autoload :Base,             'makara2/connection_proxy/base'
    autoload :Mysql2,           'makara2/connection_proxy/mysql2'
  end

  module Errors
    autoload :AllConnectionsBlacklisted,  'makara2/errors/all_connections_blacklisted'
    autoload :BlacklistConnection,        'makara2/errors/blacklist_connection'
  end

end
