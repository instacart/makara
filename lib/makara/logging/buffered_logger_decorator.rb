module Makara
  module Logging

    module BufferedLoggerDecorator

      def add(severity, message = nil, progname = nil, &block)
        message = makara_formatter.call(severity, Time.now, progname, message)
        super(severity, message, progname, &block)
      end

      def makara_formatter
        @makara_formatter ||= ::Makara::Logging::Formatter.new
      end
    end

  end
end