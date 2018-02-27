module Makara
  module Logging
    class Logger

      class << self

        def log(msg, format = :error)
          logger.send(format, "[Makara] #{msg}") if logger
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
