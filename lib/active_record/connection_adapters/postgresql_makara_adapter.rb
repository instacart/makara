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
        ::ActiveRecord::Base.postgresql_connection(config)
      end

    end
  end
end
