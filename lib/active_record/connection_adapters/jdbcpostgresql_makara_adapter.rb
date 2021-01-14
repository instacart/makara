require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/jdbcpostgresql_adapter'
require 'active_record/connection_adapters/postgresql_makara_adapter'

module ActiveRecord
  module ConnectionHandling
    def jdbcpostgresql_makara_connection(config)
      postgresql_makara_connection(config)
    end
  end
end
