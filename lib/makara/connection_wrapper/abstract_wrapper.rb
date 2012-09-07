module Makara
  module ConnectionWrapper

    class AbstractWrapper
      INFINITE_BLACKLIST_TIME = -1

      attr_reader :name, :connection, :blacklisted_until

      delegate :execute, :to => :connection

      def initialize(name, connection)
        @name = name
        @connection = decorate_connection(connection)
      end

      def blacklisted?
        return false if blacklisted_until.nil?
        return true if blacklisted_until == INFINITE_BLACKLIST_TIME
        blacklisted_until.to_i > Time.now.to_i
      end

      def blacklist!(until_time = 1.minute)
        return if self.master?
        self.blacklisted_until = until_time
      end

      def slave?
        !self.master?
      end
      
    end

  end
end