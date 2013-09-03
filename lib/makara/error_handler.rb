# Base class to handle errors when invoking an underlying connection from a makara proxy.
# Each concrete implementation of a MakaraProxy can provide it's own ErrorHandler which should inherit
# from this class.

module Makara
  class ErrorHandler


    def handle(connection)
      yield

    rescue Exception => e
      gracefully(connection, e)
    end


    protected


    def gracefully(connection, e)
      raise Makara::Errors::BlacklistConnection.new(connection, e)
    end


    def harshly(e)
      raise e 
    end

  end
end