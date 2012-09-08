module Makara
  module ConnectionWrapper

    # wraps the connection, allowing it to:
    #   - have a name
    #   - be blacklisted
    #   - answer questions about it's role
    class AbstractWrapper

      attr_reader :name, :connection

      delegate :execute, :to => :connection

      def initialize(connection, name = nil, blacklist_duration = nil)
        @connection = connection
        @config = @connection.instance_variable_get('@config') || {}

        @name = @config.delete(:name) || name
        @blacklist_duration = @config.delete(:blacklist_duration).try(:seconds) || blacklist_duration
      end

      def blacklisted?
        blacklisted = @blacklisted_until.to_i > Time.now.to_i
        if @previously_blacklisted && !blacklisted
          @previously_blacklisted = false
          self.connection.reconnect!
        end
        blacklisted
      end

      def blacklist!
        for_length = @blacklist_duration
        for_length = 0.seconds if self.master?
        for_length ||= 1.minute

        @previously_blacklisted = true
        @blacklisted_until = for_length.from_now
      end

      def slave?
        !self.master?
      end

      def to_s
        @name || (self.master? ? 'master' : 'slave')
      end

      def inspect
        "#<#{self.class.name} name: #{@name}, #{@config.map{|k,v| "#{k}: #{v || 'nil'}" }.join(', ')} >"
      end

    end

  end
end