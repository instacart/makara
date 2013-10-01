require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/jdbcmysql_adapter'
require 'active_record/connection_adapters/makara_mysql2_adapter'

if ActiveRecord::VERSION::MAJOR >= 4

  module ActiveRecord
    module ConnectionHandling
      def makara_jdbcmysql_connection(config)
        makara_mysql2_connection(config)
      end
    end
  end
else
  module ActiveRecord
    class Base
      def self.makara_jdbcmysql_connection(config)
        self.makara_mysql2_connection(config)
      end
    end
  end

end
