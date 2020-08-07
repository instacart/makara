module Makara
  module Errors
    class BlacklistConnectionOnMaster < MakaraError

      attr_reader :original_error

      def initialize(connection, error)
        @original_error = error
        super "[Makara/#{connection._makara_name}] master connection blacklisted (reraise on first error) #{error.message}."
      end

    end
  end
end
