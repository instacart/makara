module Makara2
  class ErrorHandler


    def handle(connection)
      yield

    rescue Exception => e
      gracefully(connection, e)
    end


    protected


    def gracefully(connection, e)
      raise Makara2::Errors::BlacklistConnection.new(connection, e)
    end


    def harshly(e)
      raise e 
    end

  end
end