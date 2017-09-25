require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/postgresql_adapter'

if ActiveRecord::VERSION::MAJOR >= 4

  module ActiveRecord
    module ConnectionHandling
      def makara_postgresql_connection(config)
        ActiveRecord::ConnectionAdapters::MakaraPostgreSQLAdapter.new(config)
      end
    end
  end

else

  module ActiveRecord
    class Base
      def self.makara_postgresql_connection(config)
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
      end

      PSQL_SQL_MASTER_MATCHERS = [/\A\s*select.+nextval\(/i].map(&:freeze).freeze
      PSQL_SQL_SLAVE_MATCHERS  = [/\A\s*show\s/i].map(&:freeze).freeze

      def sql_master_matchers
        SQL_MASTER_MATCHERS + PSQL_SQL_MASTER_MATCHERS
      end

      def sql_slave_matchers
        SQL_SLAVE_MATCHERS + PSQL_SQL_SLAVE_MATCHERS
      end

      protected

      def active_record_connection_for(config)
        ::ActiveRecord::Base.postgresql_connection(config)
      end

    end
  end
end
