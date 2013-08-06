require 'active_record/connection_adapters/makara_adapter'

module ActiveRecord
  class Base
    def self.makara_sqlite3_connection(config)
      config[:db_adapter] = 'sqlite3'
      self.makara_connection(config)
    end
  end
end