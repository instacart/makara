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
        # Rails 7.2+: Use new_client instead of deprecated postgresql_connection
        # Filter out Makara-specific config options that PostgreSQL doesn't recognize
        makara_options = [:master_ttl, :slave_ttl, :blacklist_duration, :sticky,
                          :master_strategy, :slave_strategy, :connections]
        filtered_config = config.except(*makara_options)
        ::ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new_client(filtered_config)
      end

    end
  end
end
