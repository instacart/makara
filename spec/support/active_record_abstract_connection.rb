class ActiveRecord::Base
  def self.abstract_connection(config)
    ActiveRecord::ConnectionAdapters::AbstractAdapter.new(config)
  end
end