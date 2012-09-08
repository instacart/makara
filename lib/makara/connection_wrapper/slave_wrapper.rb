module Makara
  module ConnectionWrapper
    
    class SlaveWrapper < AbstractWrapper

      attr_accessor :next_slave

      def master?
        false
      end

      def next

        if self.singular?
          return safe_slave_value(self)
        end

        slave = self.next_slave

        while slave.blacklisted?
          slave = slave.next_slave

          #we've looped all the way around
          if slave == self 
            return safe_slave_value(slave) 
          end

        end 

        safe_slave_value(slave)
      end

      def singular?
        self.next_slave == self
      end

      protected

      def safe_slave_value(slave)
        slave.blacklisted? ? nil : slave
      end

    end

  end
end