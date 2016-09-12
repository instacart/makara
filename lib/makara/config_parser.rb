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

    # ConnectionUrlResolver is borrowed from Rails 4-2 since its location and implementation
    # vary slightly among Rails versions, but the behavior is the same.  Thus, borrowing the
    # class should be the most future-safe way to parse a database url.
    #
    # Expands a connection string into a hash.
    class ConnectionUrlResolver # :nodoc:

      # == Example
      #
      #   url = "postgresql://foo:bar@localhost:9000/foo_test?pool=5&timeout=3000"
      #   ConnectionUrlResolver.new(url).to_hash
      #   # => {
      #     "adapter"  => "postgresql",
      #     "host"     => "localhost",
      #     "port"     => 9000,
      #     "database" => "foo_test",
      #     "username" => "foo",
      #     "password" => "bar",
      #     "pool"     => "5",
      #     "timeout"  => "3000"
      #   }
      def initialize(url)
        raise "Database URL cannot be empty" if url.blank?
        @uri     = URI.parse(url)
        @adapter = @uri.scheme.tr('-', '_')
        @adapter = "postgresql" if @adapter == "postgres"

        if @uri.opaque
          @uri.opaque, @query = @uri.opaque.split('?', 2)
        else
          @query = @uri.query
        end
      end

      # Converts the given URL to a full connection hash.
      def to_hash
        config = raw_config.reject { |_,value| value.blank? }
        config.map { |key,value| config[key] = URI.unescape(value) if value.is_a? String }
        config
      end

      private

      def uri
        @uri
      end

      # Converts the query parameters of the URI into a hash.
      #
      #   "localhost?pool=5&reaping_frequency=2"
      #   # => { "pool" => "5", "reaping_frequency" => "2" }
      #
      # returns empty hash if no query present.
      #
      #   "localhost"
      #   # => {}
      def query_hash
        Hash[(@query || '').split("&").map { |pair| pair.split("=") }]
      end

      def raw_config
        if uri.opaque
          query_hash.merge({
            "adapter"  => @adapter,
            "database" => uri.opaque })
        else
          query_hash.merge({
            "adapter"  => @adapter,
            "username" => uri.user,
            "password" => uri.password,
            "port"     => uri.port,
            "database" => database_from_path,
            "host"     => uri.host })
        end
      end

      # Returns name of the database.
      def database_from_path
        if @adapter == 'sqlite3'
          # 'sqlite3:/foo' is absolute, because that makes sense. The
          # corresponding relative version, 'sqlite3:foo', is handled
          # elsewhere, as an "opaque".

          uri.path
        else
          # Only SQLite uses a filename as the "database" name; for
          # anything else, a leading slash would be silly.

          uri.path.sub(%r{^/}, "")
        end
      end
    end

    # NOTE: url format must be, e.g.
    # url: mysql2://...
    # NOT
    # url: mysql2_makara://...
    # since the '_' in the protocol (mysql2_makara) makes the URI invalid
    # NOTE: Does not use ENV['DATABASE_URL']
    def self.merge_and_resolve_default_url_config(config)
      if ENV['DATABASE_URL']
        Logging::Logger.log "Please rename DATABASE_URL to use in the database.yml", :warn
      end
      return config unless config.key?(:url)
      url = config[:url]
      url_config = ConnectionUrlResolver.new(url).to_hash
      url_config = url_config.symbolize_keys
      url_config.delete(:adapter)
      config.delete(:url)
      config.update(url_config)
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
      all_configs
        .select { |config| config[:role] == 'master' }
        .map { |config| config.except(:role) }
    end


    def slave_configs
      all_configs
        .reject { |config| config[:role] == 'master' }
        .map { |config| config.except(:role) }
    end


    protected


    def all_configs
      @makara_config[:connections].map do |connection|
        base_config.merge(makara_config.except(:connections))
                   .merge(connection.symbolize_keys)
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
