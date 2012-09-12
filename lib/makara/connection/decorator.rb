module Makara
  
  module Connection
    # module which gets extended on adapter instances
    # provides a way to reference the connection list
    # overrides execute so it will delegate to the connection list once
    module Decorator

      (::ActiveRecord::ConnectionAdapters::MakaraAdapter::MASS_DELEGATION_METHODS + ['execute']).each do |meth|
        module_eval <<-MEV, __FILE__, __LINE__ + 1
          def #{meth}(*args)
            with_makara do |acceptor|
              return (defined?(super) ? super : nil) if acceptor.nil?
              acceptor.#{meth}(*args)
            end
          end
        MEV
      end

      def makara
        @makara_adapter
      end

      # set the connection list
      def makara_adapter=(adapter)
        @makara_adapter = adapter
      end

      # if we have a connection list and we're not alrady hijacked,
      # allow the connection list to handle the execute
      def with_makara
        if @makara_adapter && !@makara_adapter.hijacking?
          yield @makara_adapter
        else
          yield nil
        end
      end
    end
  end
end