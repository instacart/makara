require 'makara/railtie' if defined?(Rails)

module Makara

  autoload :ConfigParser,               'makara/config_parser'
  autoload :Middleware,                 'makara/middleware'
  autoload :VERSION,                    'makara/version'

  module Connection
    autoload :Decorator,                'makara/connection/decorator'
    autoload :ErrorHandler,             'makara/connection/error_handler'
    autoload :Group,                    'makara/connection/group'
    autoload :Wrapper,                  'makara/connection/wrapper'
  end

  module Logging
    autoload :BufferedLoggerDecorator,  'makara/logging/buffered_logger_decorator'
    autoload :Formatter,                'makara/logging/formatter'                
  end

  class << self
    # logging helpers
    %w(info error warn).each do |log_method|
      class_eval <<-LOG_METH, __FILE__, __LINE__ + 1
        def #{log_method}(msg)
          return unless verbose?
          msg = "[Makara] \#{msg}"
          ActiveRecord::Base.logger.#{log_method}(msg)
        end
      LOG_METH
    end

    def verbose!
      @verbose = true
    end

    def verbose?
      @verbose
    end

    def connection
      return nil unless ActiveRecord::Base.connection.respond_to?(:unstick!)
      ActiveRecord::Base.connection
    end

  end
end

require 'active_record/connection_adapters/makara_adapter'