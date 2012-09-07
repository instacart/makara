# builds connections based on your database.yml
# strips some of this logic from rails directly
module Makara
  module ConnectionBuilder
    class << self


      # based on a single-level config hash, strip the adapter and build a specification for the
      # adapter being used. actual establishment of the connection should be handled later
      def extract_connection_from_config(config, default_name = nil, is_master = false)
        adapter_config = extract_base_config(config)

        name = adapter_config.delete(:name) || default_name || 'adapter'
        adapter_method = "#{adapter_config[:adapter]}_connection"

        wrapper_class(is_master).new(name, ConnectionSpecification.new(adapter_config, adapter_method))
      end


      # look for a set of slave configs and build them.
      # use the top-level configurations as the starting point so only the differences need to be defined.
      def extract_slaves_from_config(config)
        base_config = extract_base_config(config)

        previous = nil

        all_slaves = each_slave_config(base_config) do |slave_config, i|        

          slave = extract_connection_from_config(slave_config, "slave_#{i}", false)

          # create a singly linked list (reversed order, but we don't care at this point)
          slave.next_slave = previous
          previous = slave
          slave
        end

        all_slaves.first.try(:next_slave=, all_slaves.last)
        all_slaves
      end

      protected

      # pull this out so we can stub easily
      # use the connection wrapper based on if this is from a master config
      def wrapper_class(is_master = false)
        (is_master ? ::Makara::ConnectionWrapper::MasterWrapper : ::Makara::ConnectionWrapper::SlaveWrapper)
      end

      # provide a way to easily iterate slave configs, building connections along the way
      # provides an iterator with the slave config and the # of the config (1..n)
      def each_slave_config(base_config = {})
        i = 0
        [*config[:slaves]].compact.map do |config| 
          i += 1
          config = config.reverse_merge(base_config)
          yield config, i
        end
      end

      # strip out the makara-only configuration keys
      def extract_base_config(whole)
        whole = whole.symbolize_keys
        whole.except(:slaves, :sticky_slaves, :sticky_master)
      end

    end
  end
end