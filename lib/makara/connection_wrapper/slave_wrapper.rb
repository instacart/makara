module Makara
  module ConnectionWrapper
    
    class SlaveWrapper < AbstractWrapper
      def master?
        false
      end
    end

  end
end