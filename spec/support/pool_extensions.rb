module PoolExtensions

  def connections
    @connections
  end

  def current_index
    @current_index
  end

  def context
    @context
  end

  def error_handler
    @error_handler
  end

  def config
    @config
  end

  def blacklist_at!(idx)
    @current_index = idx
    blacklist!
  end

  def connection_count
    @connections.length
  end

end


Makara2::Pool.send(:include, PoolExtensions)