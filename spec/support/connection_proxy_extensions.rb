module ConnectionProxyExtensions

  def master_pool
    @master_pool
  end

  def slave_pool
    @slave_pool
  end

  def master_context
    @master_context
  end

  def id
    @id
  end

  def master_for?(sql)
    pool_for(sql) == master_pool
  end

  def would_stick?(sql)
    should_stick?(sql)
  end

  def connection_for(sql)
    pool_for(sql) do |pool|
      pool.provide do |connection|
        connection
      end
    end
  end

  def pool_for(sql)
    appropriate_pool(sql) do |pool|
      pool
    end
  end

end

Makara2::ConnectionProxy::Base.send(:include, ConnectionProxyExtensions)