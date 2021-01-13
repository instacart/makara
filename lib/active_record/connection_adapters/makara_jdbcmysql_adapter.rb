require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/jdbcmysql_adapter'
require 'active_record/connection_adapters/makara_mysql2_adapter'

module ActiveRecord
  module ConnectionHandling
    def makara_jdbcmysql_connection(config)
      makara_mysql2_connection(config)
    end
  end
end
