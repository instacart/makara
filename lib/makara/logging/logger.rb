module Makara
  module Logging
    class Logger

      class << self

        def log(msg, format = :info)
          logger.send(format, msg) if logger
        end

        def logger
          @logger
        end

        def logger=(l)
          @logger = l
        end

      end

    end
  end
end
