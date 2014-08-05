require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/jdbcpostgresql_adapter'
require 'active_record/connection_adapters/postgresql_makara_adapter'

if ActiveRecord::VERSION::MAJOR >= 4

  module ActiveRecord
    module ConnectionHandling
      def jdbcpostgresql_makara_connection(config)
        postgresql_makara_connection(config)
      end
    end
  end

else

  module ActiveRecord
    class Base
      def self.jdbcpostgresql_makara_connection(config)
        self.postgresql_makara_connection(config)
      end
    end
  end

end
