module ProxyExtensions

  attr_reader :master_pool, :slave_pool, :master_context, :id
  
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
