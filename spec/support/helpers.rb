module SpecHelpers
  def establish_connection(config)
    connection = ActiveRecord::Base.establish_connection(config)

    # make sure these are all reset to not be blocklisted
    ActiveRecord::Base.connection.slave_pool.connections.each(&:_makara_unblock!)
    ActiveRecord::Base.connection.master_pool.connections.each(&:_makara_unblock!)

    ActiveRecord::Base.connection
  end

  def config(masters = 1, slaves = 2)
    connections = []
    masters.times{ connections << {:role => 'master'} }
    slaves.times{ connections << {:role => 'slave'} }
    {
      :makara => {
        # Defaults:
        # :master_ttl => 5,
        # :blocklist_duration => 30,
        # :sticky => true
        :id => 'mock_mysql',
        :connections => connections
      }
    }
  end
end
