module Makara
  module ConnectionBuilder
    class << self


      def extract_connection_from_config(config, default_name = nil, is_master = false)
        adapter_config = extract_base_config(config)

        name = adapter_config.delete(:name) || default_name || 'adapter'
        adapter_method = "#{adapter_config[:adapter]}_connection"

        wrapper_class(is_master).new(name, ConnectionSpecification.new(adapter_config, adapter_method))
      end

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
      def wrapper_class(is_master = false)
        (is_master ? ::Makara::ConnectionWrapper::MasterWrapper : ::Makara::ConnectionWrapper::SlaveWrapper)
      end


      def each_slave_config(base_config = {})
        i = 0
        [*config[:slaves]].compact.map do |config| 
          i += 1
          config = config.reverse_merge(base_config)
          yield config, i
        end
      end

      def extract_base_config(whole)
        whole = whole.symbolize_keys
        whole.except(:slaves, :sticky_slaves, :sticky_master)
      end

    end
  end
end