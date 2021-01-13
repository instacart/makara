require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/postgis_adapter'

module ActiveRecord
  module ConnectionHandling
    def makara_postgis_connection(config)
      ActiveRecord::ConnectionAdapters::MakaraPostgisAdapter.new(config)
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class MakaraPostgisAdapter < ActiveRecord::ConnectionAdapters::MakaraAbstractAdapter
      def self.visitor_for(*args)
        ActiveRecord::ConnectionAdapters::PostGISAdapter.visitor_for(*args)
      end

      protected

      def active_record_connection_for(config)
        ::ActiveRecord::Base.postgis_connection(config)
      end
    end
  end
end
