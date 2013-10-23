module PoolExtensions

  def connections
    @connections
  end

  def connection_count
    @connections.length
  end

end


Makara::Pool.send(:include, PoolExtensions)
