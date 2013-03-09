require 'active_record/connection_adapters/makara_adapter'

module ActiveRecord
  class Base
    def self.makara_postgresql_connection(config)
      config[:db_adapter] = 'postgresql'
      self.makara_connection(config)
    end
  end
end