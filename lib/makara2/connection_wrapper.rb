module Makara2
  class ConnectionWrapper < ::SimpleDelegator

    def initialize(connection, config)
      @config = config
      super(connection)
    end

    def weight
      @config[:weight] || 1
    end

    def blacklisted?
      @blacklisted_until.to_i > Time.now.to_i
    end

    def blacklist!
      @blacklisted_until = Time.now.to_i + @config[:blacklist_duration]
    end

  end
end