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
      end

      protected

      def active_record_connection_for(config)
        # Rails 7.2+: Create a full PostgreSQLAdapter instance
        # The old postgresql_connection method was removed, so we call .new directly
        # This returns a complete adapter instance, not just a raw PG connection
        ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(config)
      end

    end
  end
end
