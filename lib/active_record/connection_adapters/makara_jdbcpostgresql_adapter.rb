require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/jdbcpostgresql_adapter'
require 'active_record/connection_adapters/makara_postgresql_adapter'

if ActiveRecord::VERSION::MAJOR >= 4

  module ActiveRecord
    module ConnectionHandling
      def makara_jdbcpostgresql_connection(config)
        makara_postgresql_connection(config)
      end
    end
  end
else
  module ActiveRecord
    class Base
      def self.makara_jdbcpostgresql_connection(config)
        self.makara_postgresql_connection(config)
      end
    end
  end

end
