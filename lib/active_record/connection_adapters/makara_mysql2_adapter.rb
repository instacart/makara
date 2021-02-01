require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/mysql2_adapter'

module ActiveRecord
  module ConnectionHandling
    def makara_mysql2_connection(config)
      ActiveRecord::ConnectionAdapters::MakaraMysql2Adapter.new(config)
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class MakaraMysql2Adapter < ActiveRecord::ConnectionAdapters::MakaraAbstractAdapter
      class << self
        def visitor_for(*args)
          ActiveRecord::ConnectionAdapters::Mysql2Adapter.visitor_for(*args)
        end
      end

      protected

      def active_record_connection_for(config)
        ::ActiveRecord::Base.mysql2_connection(config)
      end
    end
  end
end
