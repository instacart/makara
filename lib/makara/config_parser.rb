require 'digest/md5'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/hash/except'

# Convenience methods to grab subconfigs out of the primary configuration.
# Provides a way to generate a consistent ID based on a unique config.
# Makara configs should be formatted like so:
# --
#   top_level: 'variable'
#   another: 'top level variable'
#   makara:
#     master_ttl: 3
#     blacklist_duration: 20
#     connections:
#       - role: 'master'
#       - role: 'slave'
#       - role: 'slave'
#         name: 'slave2'

module Makara
  class ConfigParser

    DEFAULTS = {
      :master_ttl => 5,
      :blacklist_duration => 30,
      :sticky => true
    }

    # NOTE: url format must be, e.g.
    # url: mysql2://...
    # NOT
    # url: mysql2_makara://...
    # since the '_' in the protocol (mysql2_makara) makes the URI invalid
    # NOTE: Does not use ENV['DATABASE_URL']
    def self.merge_and_resolve_default_url_config(config)
      return config unless config.key?(:url)
      url_config = config.slice(:url)
      url_config = connection_url_to_hash(url_config)
      url_config = url_config[:url].symbolize_keys
      url_config.delete(:adapter)
      config.delete(:url)
      config.update(url_config)
    end

    def self.connection_url_to_hash(url_config)
      if defined?(ActiveRecord::ConnectionHandling::MergeAndResolveDefaultUrlConfig)
        ActiveRecord::ConnectionHandling::MergeAndResolveDefaultUrlConfig.new(url_config).resolve
      elsif defined?(ActiveRecord::Core::ConnectionSpecification::Resolver)
        {
          :url =>
          ActiveRecord::Core::ConnectionSpecification::Resolver.send(:connection_url_to_hash, url_config[:url])
        }
      else
        fail 'Unknown connection_url_hash method'
      end
    end

    attr_reader :makara_config

    def initialize(config)
      @config = config.symbolize_keys
      @makara_config = DEFAULTS.merge(@config[:makara] || {})
      @makara_config = @makara_config.symbolize_keys
      @id = @makara_config[:id]
    end


    def id
      @id ||= begin
        sorted = recursive_sort(@config)
        Digest::MD5.hexdigest(sorted.to_s)
      end
    end


    def master_configs
      all_configs.
        select{|config| config[:role] == 'master' }.
        map{|config| config.except(:role) }
    end


    def slave_configs
      all_configs.
        reject{|config| config[:role] == 'master' }.
        map{|config| config.except(:role) }
    end


    protected


    def all_configs
      @makara_config[:connections].map do |connection|
        base_config.merge(connection.symbolize_keys)
      end
    end


    def base_config
      @base_config ||= DEFAULTS.merge(@config).except(:makara)
    end


    def recursive_sort(thing)
      return thing.to_s unless thing.include?(Enumerable)

      thing.map do |part|
        recursive_sort(part)
      end

      thing.sort_by(&:to_s)

    end

  end
end
