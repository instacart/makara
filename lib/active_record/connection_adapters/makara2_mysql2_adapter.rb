require 'active_record/connection_adapters/makara2_abstract_adapter'
require 'active_record/connection_adapters/mysql2_adapter'

module ActiveRecord
  module ConnectionHandling
    def makara2_mysql2_connection(config)
      ActiveRecord::ConnectionAdapters::Makara2Mysql2Adapter.new(config)
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class Makara2Mysql2Adapter < ActiveRecord::ConnectionAdapters::Makara2AbstractAdapter

      protected

      def connection_for(config)
        ::ActiveRecord::Base.mysql2_connection(config)
      end

    end
  end
end