# builds connections based on your database.yml
# strips some of this logic from rails directly
module Makara
  module ConnectionBuilder
    class << self

      # look for a set of slave configs and build them.
      # use the top-level configurations as the starting point so only the differences need to be defined.
      def build_slave_linked_list(slave_connections)

        previous = nil

        all_slaves = slave_connections.map do |slave_connection|        

          slave = ::Makara::ConnectionWrapper::SlaveWrapper.new(slave_connection)
          # create a singly linked list (reversed order, but we don't care at this point)
          slave.next_slave = previous
          previous = slave
          slave
        end

        all_slaves.first.try(:next_slave=, all_slaves.last)
        all_slaves
      end


      # provide a way to easily iterate slave configs, building connections along the way
      # provides an iterator with the slave config and the # of the config (1..n)
      def each_slave_config(base_config = {})
        i = 0

        [*base_config[:slaves]].compact.map do |config| 
          i += 1

          config = config.reverse_merge(base_config)
          config = apply_adapter_name(config)
          config.reverse_merge!(:name => "slave_#{i}")

          yield extract_base_config(config)

        end
      end

      def master_config(config)
        config = apply_adapter_name(config)
        extract_base_config(config)
      end

      protected

      def apply_adapter_name(config)
        db_adapter = config[:db_adapter] || config[:adapter]
        config.merge(:adapter => db_adapter)
      end

      # pull this out so we can stub easily
      # use the connection wrapper based on if this is from a master config
      def wrapper_class(is_master = false)
        (is_master ? ::Makara::ConnectionWrapper::MasterWrapper : ::Makara::ConnectionWrapper::SlaveWrapper)
      end

      # strip out the makara-only configuration keys
      def extract_base_config(whole)
        whole = whole.symbolize_keys
        whole.except(:slaves, :db_adapter, :sticky_slaves, :sticky_master, :verbose)
      end

    end
  end
end