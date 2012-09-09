# builds connections based on your database.yml
# strips some of this logic from rails directly
module Makara
  module ConfigParser
    class << self

      # provide a way to easily iterate slave configs, building connections along the way
      # provides an iterator with the slave config and the # of the config (1..n)
      def each_config(full_config = {})
        full_config = full_config.symbolize_keys

        shared = shared_config(full_config)

        [*full_config[:databases]].compact.map do |config| 

          config = config.reverse_merge(shared)
          config = apply_adapter_name(config)

          yield extract_base_config(config)

        end
      end

      protected


      def shared_config(config)
        config = apply_adapter_name(config)
        extract_base_config(config)
      end

      def apply_adapter_name(config)
        db_adapter = config[:db_adapter] || config[:adapter]
        config.merge(:adapter => db_adapter)
      end

      # strip out the top-level makara configuration keys
      def extract_base_config(whole)
        whole = whole.symbolize_keys
        whole.except(:databases, :db_adapter, :sticky_slave, :sticky_slaves, :sticky_master, :verbose)
      end

    end
  end
end