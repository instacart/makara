require 'active_record/connection_adapters/mysql2_adapter'

module ActiveRecord
  module ConnectionHandling
    def makara2_mysql2_connection(config)
      config = config.symbolize_keys

      config[:username] ||= 'root'

      if Mysql2::Client.const_defined? :FOUND_ROWS
        config[:flags] = Mysql2::Client::FOUND_ROWS
      end


      client = Makara2::ConnectionProxy::Mysql2.new(config)
      options = [config[:host], config[:username], config[:password], config[:database], config[:port], config[:socket], 0]

      ActiveRecord::ConnectionAdapters::Mysql2Adapter.new(client, logger, options, config)
    end
  end
end