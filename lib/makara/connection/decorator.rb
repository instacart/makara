module Makara
  
  module Connection
    # module which gets extended on adapter instances
    # overrides execute so it will delegate to the makara adapter once
    module Decorator

      # if we have a makara adapter and we're not alrady hijacked,
      # allow the adapter to handle the execute
      def with_makara
        adapter = Makara.connection
        if adapter && !adapter.hijacking?
          yield adapter
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