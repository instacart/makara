module Makara
  module ConnectionWrapper
    
    class MasterWrapper < AbstractWrapper
      def master?
        true
      end
    end
    
  end
end