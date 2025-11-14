require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/postgresql_adapter'

if ActiveRecord::VERSION::MAJOR >= 4

  module ActiveRecord
    module ConnectionHandling
      def postgresql_makara_connection(config)
        ActiveRecord::ConnectionAdapters::MakaraPostgreSQLAdapter.new(config)
      end
    end
  end

else

  module ActiveRecord
    class Base
      def self.postgresql_makara_connection(config)
        ActiveRecord::ConnectionAdapters::MakaraPostgreSQLAdapter.new(config)
      end
    end
  end

end

module ActiveRecord
  module ConnectionAdapters
    class MakaraPostgreSQLAdapter < ActiveRecord::ConnectionAdapters::MakaraAbstractAdapter

      class << self
        def visitor_for(*args)
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.visitor_for(*args)
        end

        def column_name_matcher
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.column_name_matcher
        end

        def column_name_with_order_matcher
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.column_name_with_order_matcher
        end

        def quote_table_name(table_name)
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.quote_table_name(table_name)
        end

        def quote_column_name(column_name)
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.quote_column_name(column_name)
        end
      end

      protected

      def active_record_connection_for(config)
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(config)
      end

    end
  end
end
