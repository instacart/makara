require 'makara/railtie' if defined?(Rails)

module Makara

  autoload :ConfigParser,           'makara/config_parser'

  autoload :Middleware,             'makara/middleware'
  autoload :VERSION,                'makara/version'

  module Connection
    autoload :Decorator,    'makara/connection/decorator'
    autoload :Group,        'makara/connection/group'
    autoload :Wrapper,      'makara/connection/wrapper'
  end

  module Logging
    autoload :BufferedLoggerDecorator,  'makara/logging/buffered_logger_decorator'
    autoload :Formatter,                'makara/logging/formatter'                
  end

end

require 'active_record/connection_adapters/makara_adapter'