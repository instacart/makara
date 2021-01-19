module SpecHelpers
  def establish_connection(config)
    connection = ActiveRecord::Base.establish_connection(config)

    # make sure these are all reset to not be blacklisted
    ActiveRecord::Base.connection.replica_pool.connections.each(&:_makara_whitelist!)
    ActiveRecord::Base.connection.master_pool.connections.each(&:_makara_whitelist!)

    ActiveRecord::Base.connection
  end

  def config(masters = 1, replicas = 2)
    connections = []
    masters.times{ connections << {role: 'master'} }
    replicas.times{ connections << {role: 'replica'} }
    {
      makara: {
        # Defaults:
        # :master_ttl => 5,
        # :blacklist_duration => 30,
        # :sticky => true
        id: 'mock_mysql',
        connections: connections
      }
    }
  end
end
