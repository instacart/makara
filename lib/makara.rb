require 'makara/railtie' if defined?(Rails)

module Makara

  autoload :VERSION,            'makara/version'
  autoload :ConnectionWrapper,  'makara/connection_wrapper'
  autoload :ConnectionBuilder,  'makara/connection_builder'
  autoload :Middleware,         'makara/middleware'


  module Logging
    autoload :BufferedLoggerDecorator,  'makara/logging/buffered_logger_decorator'
    autoload :Formatter,                'makara/logging/formatter'
  end

end

require 'active_record/connection_adapters/makara_adapter'