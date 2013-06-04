module Makara
  
  module Connection
    # module which gets extended on adapter instances
    # overrides execute so it will delegate to the makara adapter once
    module Decorator

      def self.extended(base)
        base.instance_eval do
          def logger
            @logger
          end unless self.respond_to?(:logger) # rails 3.0.x compatability
        end
      end

      def makara_adapter
        @makara_adapter
      end

      def makara_adapter=(adapter)
        @makara_adapter = adapter
      end

      # if we have a makara adapter and we're not alrady hijacked,
      # allow the adapter to handle the execute
      def with_makara
        if makara_adapter && !makara_adapter.hijacking?
          yield makara_adapter
        else
          yield nil
        end
      end

      def execute(*args)
        with_makara do |acceptor|
          return (defined?(super) ? super : nil) if acceptor.nil?
          acceptor.execute(*args)
        end
      end

      def exec_query(*args)
        with_makara do |acceptor|
          return (defined?(super) ? super : nil) if acceptor.nil?
          acceptor.exec_query(*args)
        end
      end
    end
  end
end