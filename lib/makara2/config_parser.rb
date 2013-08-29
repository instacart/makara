# convenience methods to grab subconfigs out of the primary database.yml configuration.

module Makara2
  class ConfigParser

    def initialize(config)
      @config = config
    end

    def master_configs
      all_configs.select{|config| config['role'] == 'master' }
    end

    def slave_configs
      all_configs.reject{|config| config['role'] == 'master' }
    end

    protected

    def all_configs
      @config[:connections].map do |connection|
        base_config.merge(connection)
      end
    end

    def base_config
      @config.except(:connections, :sticky_slave, :sticky_master, :blacklist_duration)
    end

  end
end