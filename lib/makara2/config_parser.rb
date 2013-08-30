require 'digest/md5'
require 'active_support/core_ext/hash/keys'

# convenience methods to grab subconfigs out of the primary database.yml configuration.
module Makara2
  class ConfigParser

    def initialize(config)
      @config = config.symbolize_keys
      @id = @config[:id]
    end


    def id
      @id ||= begin
        sorted = recursive_sort(@config)
        Digest::MD5.hexdigest(sorted.to_s)
      end
    end


    def master_configs
      all_configs.select{|config| config[:role] == 'master' }
    end

    def slave_configs
      all_configs.reject{|config| config[:role] == 'master' }
    end

    protected

    def all_configs
      @config[:connections].map do |connection|
        base_config.merge(connection).symbolize_keys.except(:adapter)
      end
    end

    def base_config
      @config.except(:id, :master_ttl, :connections)
    end

    def recursive_sort(thing)
      return thing.to_s unless thing.respond_to?(:sort)

      thing.map do |part|
        recursive_sort(part)
      end

      thing.sort_by(&:to_s)

    end

  end
end