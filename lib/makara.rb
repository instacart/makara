require 'makara/railtie' if defined?(Rails)

module Makara

  autoload :ConfigParser,   'makara/config_parser'
  autoload :Middleware,     'makara/middleware'
  autoload :VERSION,        'makara/version'

  module Connection
    autoload :Decorator,    'makara/connection/decorator'
    autoload :ErrorHandler, 'makara/connection/error_handler'
    autoload :Group,        'makara/connection/group'
    autoload :Wrapper,      'makara/connection/wrapper'
  end

  module Logging
    autoload :Subscriber,   'makara/logging/subscriber'
  end

  class << self

    def reset!
      @adapters = []
    end

    def register_adapter(adapter)
      @adapters ||= []
      raise "[Makara] all adapters must be given a unique name. \"#{adapter.name}\" has already been used." if @adapters.map(&:name).include?(adapter.name)
      @adapters << adapter
      @adapters = @adapters.sort_by(&:name)
    end

    def with_master(connection_indexes = nil)
      previous_values = {}
      adapters.each do |adapter|
        previous_values[adapter.name] = adapter.forced_to_master?
      end

      if connection_indexes
        connection_indexes.each do |index|
          adapters[index].force_master!
        end
      else
        adapters.each(&:force_master!)
      end

      yield

    ensure

      adapters.each do |adapter|
        unless previous_values[adapter.name]
          adapter.release_master!
        end
      end
    end

    def unstick!
      adapters.each(&:unstick!)
    end

    def adapters
      @adapters || []
    end

    def in_use?
      adapters.any?
    end

    def indexes_currently_using_master
      indexes = []
      adapters.each_with_index{|con, i| indexes << i if con.currently_master? }
      indexes
    end
  end
end

require 'active_record/connection_adapters/makara_adapter'