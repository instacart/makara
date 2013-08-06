require 'active_record/connection_adapters/makara_adapter'

module ActiveRecord
  class Base
    def self.makara_mysql2_connection(config)
      config[:db_adapter] = 'mysql2'
      self.makara_connection(config)
    end
  end
end