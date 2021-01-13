require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/jdbcpostgresql_adapter'
require 'active_record/connection_adapters/makara_postgresql_adapter'

module ActiveRecord
  module ConnectionHandling
    def makara_jdbcpostgresql_connection(config)
      makara_postgresql_connection(config)
    end
  end
end
