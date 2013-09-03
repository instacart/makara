module ProxyExtensions

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
    should_stick?(:execute, [sql])
  end

  def connection_for(sql)
    pool_for(sql) do |pool|
      pool.provide do |connection|
        connection
      end
    end
  end

  def pool_for(sql)
    appropriate_pool(:execute, [sql]) do |pool|
      pool
    end
  end

  def sticky=(s)
    @sticky = s
  end

end

Makara::Proxy.send(:include, ProxyExtensions)