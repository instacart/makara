module SpecHelpers
  def establish_connection(config)
    connection = ActiveRecord::Base.establish_connection(config)

    # make sure these are all reset to not be blacklisted
    ActiveRecord::Base.connection.slave_pool.connections.each(&:_makara_whitelist!)
    ActiveRecord::Base.connection.master_pool.connections.each(&:_makara_whitelist!)

    ActiveRecord::Base.connection
  end

  def config(masters = 1, slaves = 2)
    connections = []
    masters.times{ connections << {:role => 'master'} }
    slaves.times{ connections << {:role => 'slave'} }
    {
      :makara => {
        :blacklist_duration => 30,
        :connections => connections
      }
    }
  end
end