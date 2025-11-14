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

      # Extend PostgreSQL's Quoting ClassMethods to automatically get all class methods
      # for quoting table names, column names, and matchers. This prevents having to
      # manually add delegations for each method as Rails adds new ones.
      extend ActiveRecord::ConnectionAdapters::PostgreSQL::Quoting::ClassMethods

      class << self
        # visitor_for is not in the Quoting module, so we still delegate it manually
        def visitor_for(*args)
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.visitor_for(*args)
        end
      end

      protected

      def active_record_connection_for(config)
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(config)
      end

    end
  end
end
