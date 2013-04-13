module Makara
  module Connection
    class ErrorHandler

      delegate :current_wrapper, :to => :@adapter

      def initialize(makara_adapter)
        @adapter = makara_adapter
      end

      def handle(e)

        # we caught this exception while invoking something on the master connection, raise the error
        if current_wrapper.nil? || current_wrapper.master?
          return handle_exception_harshly(e)
        end

        case e
        when ActiveRecord::RecordNotUnique, ActiveRecord::InvalidForeignKey
          return handle_exception_harshly(e)
        when ActiveRecord::StatementInvalid
          return handle_exception_harshly(e) unless connection_message?(e)
        end

        handle_exception_gracefully(e)
      end

      protected

      def handle_exception_gracefully(e)
        # something has gone wrong, we need to release this sticky connection
        @adapter.unstick!

        # let's blacklist this slave to ensure it's removed from the slave cycle
        current_wrapper.blacklist!(e.to_s)
      end

      def handle_exception_harshly(e)
        Makara.error("Error caught in makara adapter while using #{current_wrapper}: #{e}")
        raise e 
      end

      def connection_message?(message)
        message = message.to_s.downcase

        case message
        when /(closed|lost|no)\s?(\w+)? connection/, 
             /gone away/, 
             /connection (not open|is closed)/i, 
             /reset has failed/, 
             /the database system is (starting up|shutting down)/, 
             /no connection to the server/, 
             /(could not|cannot) connect to server/,
             /result has been cleared/,
             /terminating connection/,
             /no more connections allowed/,
             /pg::error: : select/ # sometimes libpq returns the given sql query as the error message
          true
        else
          false
        end
      end
    end
  end
end
