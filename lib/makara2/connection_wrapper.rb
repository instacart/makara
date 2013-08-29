require 'active_support/core_ext/hash/keys'

module Makara2
  class ConnectionWrapper < ::SimpleDelegator

    def initialize(connection, config)
      @config = config.symbolize_keys
      super(connection)
    end

    def _makara_weight
      @config[:weight] || 1
    end

    def _makara_name
      @config[:name]
    end

    def blacklisted?
      @blacklisted_until.to_i > Time.now.to_i
    end

    def blacklist!
      @blacklisted_until = Time.now.to_i + @config[:blacklist_duration]
    end

  end
end