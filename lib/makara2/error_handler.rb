module Makara2
  class ErrorHandler


    def handle
      yield

    rescue ActiveRecord::RecordNotUnique => e
      harshly(e)
    rescue ActiveRecord::InvalidForeignKey => e
      harshly(e)
    rescue ActiveRecord::StatementInvalid => e
      if connection_message?(e)
        harshly(e)
      else
        gracefully(e)
      end
    rescue Exception => e
      gracefully(e)
    end



    protected



    def gracefully(e)
      raise Makara2::Errors::BlacklistConnection.new(e)
    end


    def harshly(e)
      raise e 
    end


    def connection_message?(message)
      message = message.to_s.downcase

      case message
      when /(closed|lost|no)\s?(\w+)? connection/, /gone away/
        true
      else
        false
      end
    end

  end
end