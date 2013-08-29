module Makara2
  module Errors
    class NoConnectionsConfigured < StandardError

      def initialize
        super "[Makara2] No connections configured"
      end
      
    end
  end
end