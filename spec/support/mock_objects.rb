require 'active_record/connection_adapters/makara2_abstract_adapter'

class FakeConnection < Struct.new(:config)
  def irespondtothis
    'hey!'
  end

  def query(content)
    []
  end
end

class FakeDatabaseAdapter < Struct.new(:config)

  def execute(sql, name = nil)
    []
  end

  def exec_query(sql, name = 'SQL', binds = [])
    []
  end

  def select_rows(sql, name = nil)
    []
  end

end

class FakeProxy < Makara2::Proxy
  def connection_for(config)
    FakeConnection.new(config)
  end

  def needs_master?(args)
    return false if args.first =~ /^select/
    true
  end
end

class FakeAdapter < ::ActiveRecord::ConnectionAdapters::Makara2AbstractAdapter
  def connection_for(config)
    FakeDatabaseAdapter.new(config)
  end
end
