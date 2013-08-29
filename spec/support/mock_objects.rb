class FakeConnection < Struct.new(:config)
  def irespondtothis
    'hey!'
  end

  def query(content)
    true
  end
end

class FakeProxy < Makara2::ConnectionProxy::Base
  def connection_for(config)
    FakeConnection.new(config)
  end
end
