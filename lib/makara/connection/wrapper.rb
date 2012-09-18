module Makara
  module Connection
    
    # wraps the connection, allowing it to:
    #   - have a name
    #   - be blacklisted
    #   - answer questions about it's role
    class Wrapper

      attr_reader :name, :connection, :weight

      delegate :execute, :to => :connection

      def initialize(connection)
        @connection         = connection
        @config             = @connection.instance_variable_get('@config') || {}

        raise "No name was provided for configuration:\n#{@config.to_yaml}" if @config[:name].blank?

        @name               = @config.delete(:name)
        @master             = @config.delete(:role) == 'master'
        @blacklist_duration = @config.delete(:blacklist_duration).try(:seconds) || 1.minute
        @weight             = @config.delete(:weight) || 1
      end

      def master?
        @master
      end

      def slave?
        !self.master?
      end

      def blacklisted?
        blacklisted = @blacklisted_until.to_i > Time.now.to_i
        if @previously_blacklisted && !blacklisted
          @previously_blacklisted = false
          begin
            self.connection.makara.hijacking! do
              self.connection.reconnect!
            end
          rescue Exception => e
            blacklist!
            return true
          end
        end
        blacklisted
      end

      def blacklist!
        for_length = @blacklist_duration
        for_length = 0.seconds if self.master?

        @previously_blacklisted = true
        @blacklisted_until = for_length.from_now
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