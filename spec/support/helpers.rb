module SpecHelpers
  def establish_connection(config)
    ActiveRecord::Base.establish_connection(config)

    # make sure these are all reset to not be blacklisted
    ActiveRecord::Base.connection.replica_pool.connections.each(&:_makara_whitelist!)
    ActiveRecord::Base.connection.primary_pool.connections.each(&:_makara_whitelist!)

    ActiveRecord::Base.connection
  end

  def config(primaries = 1, replicas = 2)
    connections = []
    primaries.times { connections << { role: 'primary' } }
    replicas.times { connections << { role: 'replica' } }
    {
      makara: {
        # Defaults:
        # :primary_ttl => 5,
        # :blacklist_duration => 30,
        # :sticky => true
        id: 'mock_mysql',
        connections: connections
      }
    }
  end
end
