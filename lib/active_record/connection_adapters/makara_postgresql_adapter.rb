require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionHandling
    def makara_postgresql_connection(config)
      ActiveRecord::ConnectionAdapters::MakaraPostgreSQLAdapter.new(config)
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class MakaraPostgreSQLAdapter < ActiveRecord::ConnectionAdapters::MakaraAbstractAdapter

      protected

      def connection_for(config)
        ::ActiveRecord::Base.postgresql_connection(config)
      end

    end
  end
end
