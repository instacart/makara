require 'active_record/connection_adapters/mysql2_adapter'

module ActiveRecord
  module ConnectionHandling
    def makara2_mysql2_connection(config)
      config = config.symbolize_keys

      config[:username] ||= 'root'

      if Mysql2::Client.const_defined? :FOUND_ROWS
        config[:flags] = Mysql2::Client::FOUND_ROWS
      end

      ActiveRecord::ConnectionAdapters::Makara2Mysql2Adapter.new(config, logger)
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class Makara2Mysql2Adapter < ::ActiveRecord::ConnectionAdapters::Mysql2Adapter

      def initialize(config, logger)
        client = Makara2::ConnectionProxy::Mysql2.new(config)
        super(client, logger, [], config)
      end

      def makara2_connection
        @connection
      end

    end
  end
end