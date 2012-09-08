module Makara
  module ConnectionWrapper

    # wraps the connection, allowing it to:
    #   - have a name
    #   - be blacklisted
    #   - answer questions about it's role
    class AbstractWrapper

      attr_reader :name, :connection

      delegate :execute, :to => :connection

      def initialize(connection, name = nil)
        @name = name || connection.instance_variable_get('@config').try(:[], :name)
        @connection = connection
      end

      def blacklisted?
        blacklisted = @blacklisted_until.to_i > Time.now.to_i
        if @previously_blacklisted && !blacklisted
          @previously_blacklisted = false
          self.connection.reconnect!
        end
        blacklisted
      end

      def blacklist!(for_length = 1.minute)
        for_length = 0.seconds if self.master?

        @previously_blacklisted = true
        @blacklisted_until = for_length.from_now
      end

      def slave?
        !self.master?
      end

    end

  end
end