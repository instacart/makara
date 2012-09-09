class ActiveRecord::Base
  def self.abstract_connection(config)
    ActiveRecord::ConnectionAdapters::AbstractAdapter.new(config)
  end
end

module AbstractAdapterConfiguration
  extend ActiveSupport::Concern

  included do
    alias_method_chain :initialize, :configery
  end
  def initialize_with_configery(*args)
    initialize_without_configery(*args)
    @config ||= @connection
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, AbstractAdapterConfiguration)