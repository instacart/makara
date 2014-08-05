require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/jdbcmysql_adapter'
require 'active_record/connection_adapters/mysql2_makara_adapter'

if ActiveRecord::VERSION::MAJOR >= 4

  module ActiveRecord
    module ConnectionHandling
      def jdbcmysql_makara_connection(config)
        mysql2_makara_connection(config)
      end
    end
  end

else

  module ActiveRecord
    class Base
      def self.jdbcmysql_makara_connection(config)
        self.mysql2_makara_connection(config)
      end
    end
  end

end
