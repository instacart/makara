require 'delegate'
require 'active_support/core_ext/hash/keys'

# Makara::ConnectionWrapper wraps the instance of an underlying connection.
# The wrapper provides methods for tracking blacklisting and individual makara configurations.
# Upon creation, the wrapper defines methods in the underlying object giving it access to the
# Makara::Proxy.

module Makara
  class ConnectionWrapper < ::SimpleDelegator

    def initialize(proxy, config, &block)
      super(nil)

      @connection_instantiation_block = block

      @config = config.symbolize_keys
      @proxy  = proxy

      __setcon__
    end

    # if we have been able to secure a connection then evaluate the given block
    def _makara_if_connected
      val = !!__getobj__
      if block_given?
        if val
          yield
        end
      else
        val
      end
    end

    def _makara_weight
      @config[:weight] || 1
    end

    def _makara_blacklisted?
      @blacklisted_until.to_i > Time.now.to_i
    end

    def _makara_blacklist!
      @blacklisted_until = Time.now.to_i + @config[:blacklist_duration]
    end

    def _makara_whitelist!
      @blacklisted_until = nil
    end

    def __setcon__

      con = @connection_instantiation_block.call
      _makara_decorate_connection(con)

      # release references
      @connection_instantiation_block = nil

      __setobj__ con

    rescue Exception => e
      if @config[:rescue_connection_failures]
        _makara_blacklist!
        nil
      else
        raise
      end
    end

    def __getobj__
      super || __setcon__
    end

    # we want to forward all private methods, since we could have kicked out from a private scenario
    # however, if we have not been able to establish a connection yet, we don't want to blow up
    def method_missing(method_name, *args, &block)
      super
    rescue NoMethodError => e
      _makara_if_connected do
        target = __getobj__
        if target.respond_to?(method_name, true)
          target.__send__(method_name, *args, &block)
        else
          raise e
        end
      end
    end


    class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
      def respond_to#{RUBY_VERSION.to_s =~ /^1.8/ ? nil : '_missing'}?(method_name, include_private = false)
        super || __getobj__.respond_to?(method_name, true)
      end
    RUBY_EVAL


    protected

    def _makara_decorate_connection(con)
      extension = %Q{
        def _makara
          @_makara
        end

        def _makara=(m)
          @_makara = m
        end

        def _makara_hijack
          if _makara.hijacked?
            yield nil
          else
            yield _makara
          end
        end

        def _makara_name
          #{@config[:name].inspect}
        end
      }

      # Each method the Makara::Proxy needs to hijack should be redefined in the underlying connection.
      # The new definition should allow for the proxy to intercept the invocation
      @proxy.class.hijack_methods.each do |meth|
        extension << %Q{
          def #{meth}(*args)
            _makara_hijack do |proxy|
              if proxy
                proxy.#{meth}(*args)
              else
                super
              end
            end
          end
        }
      end

      con.instance_eval(extension)
      con._makara = @proxy
      con._makara
    end

  end
end
