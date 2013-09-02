require 'active_record/connection_adapters/makara2_abstract_adapter'
require 'active_record/connection_adapters/postgresql_adapter'

module ActiveRecord
  module ConnectionHandling
    def makara2_postgresql_connection(config)
      ActiveRecord::ConnectionAdapters::Makara2PostgreSQLAdapter.new(config)
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class Makara2PostgreSQLAdapter < ActiveRecord::ConnectionAdapters::Makara2AbstractAdapter

      protected

      def connection_for(config)
        ::ActiveRecord::Base.postgresql_connection(config)
      end

    end
  end
end