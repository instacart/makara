module Makara
  module ConnectionWrapper
    
    class SlaveWrapper < AbstractWrapper

      attr_writer :next_slave

      def master?
        false
      end

      def next
        slave = self.next_slave
        begin
          slave = slave.next_slave
        end while slave.blacklisted? && slave != self
        
        return nil if slave.blacklisted?
        slave
      end

    end

  end
end