module Makara
  module Connection
    
    # wraps the connection, allowing it to:
    #   - have a name
    #   - be blacklisted
    #   - answer questions about it's role
    class Wrapper

      attr_reader :name, :connection, :weight
      attr_accessor :adapter

      delegate :execute, :exec_query, :to => :connection

      def initialize(adapter, connection)
        @adapter            = adapter
        @connection         = connection
        @config             = @connection.instance_variable_get('@config') || {}

        raise "No name was provided for configuration within #{@adapter.id} adapter:\n#{@config.to_yaml}" if @config[:name].blank?

        @name               = @config[:name]
        @master             = @config[:role] == 'master'
        @blacklist_duration = @config[:blacklist_duration].try(:seconds) || 1.minute
        @weight             = @config[:weight] || 1
      end

      def master?
        @master
      end

      def slave?
        !@master
      end

      def blacklisted?
        if @previously_blacklisted && @blacklisted_until.to_i <= Time.now.to_i
          @previously_blacklisted = false
          begin
            @connection.reconnect!
          rescue Exception => e
            blacklist!(e.message)
            return true
          end
        end
        @blacklisted_until.to_i > Time.now.to_i
      end

      def blacklist!(message = nil)
        for_length = @blacklist_duration
        for_length = 0.seconds if @master

        @previously_blacklisted   = true
        @blacklisted_until        = for_length.from_now

        @adapter.warn("Blacklisted #{self}: #{message}")
      end

      def to_s
        [@adapter.id, @name || (@master ? 'master' : 'slave')].compact.join('/')
      end

      def inspect
        "#<#{self.class.name} name: #{@name}, #{@config.map{|k,v| "#{k}: #{v || 'nil'}" }.join(', ')} >"
      end

    end
  end
end