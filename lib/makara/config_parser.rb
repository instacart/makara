# parses wrapper configs based on your database.yml
module Makara
  module ConfigParser
    class << self

      # provide a way to easily iterate configs
      # provides an iterator with the config of a singular connection
      def each_config(full_config = {})
        full_config = full_config.symbolize_keys

        shared = shared_config(full_config)

        [*full_config[:databases]].compact.map do |config| 

          config = config.reverse_merge(shared)
          config = apply_adapter_name(config)
          config = extract_base_config(config)

          yield config
        end
      end

      def master_config(full_config = {})
        each_config(full_config) do |config|
          return config if config[:role] == 'master'
        end
        nil
      end

      protected

      # pull out the shared information from the top-level config
      def shared_config(config)
        config = apply_adapter_name(config)
        extract_base_config(config)
      end

      # since the adapter needs to be set to makara, allow for the db_adapter
      # to be evaluated as underlying adapter name
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