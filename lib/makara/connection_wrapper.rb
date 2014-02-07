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
    end

    # have we secured a connection yet?
    def _makara_connected?
      !!@connection
    end

    # the weight of the current node
    def _makara_weight
      @config[:weight] || 1
    end

    # the name of this node
    def _makara_name
      @config[:name]
    end

    # has this node been blacklisted?
    def _makara_blacklisted?
      @blacklisted_until.to_i > Time.now.to_i
    end

    # blacklist this node for @config[:blacklist_duration] seconds
    def _makara_blacklist!
      @blacklisted_until = Time.now.to_i + @config[:blacklist_duration]
    end

    # release the blacklist
    def _makara_whitelist!
      @blacklisted_until = nil
    end

    # we delay the instantiation of the underlying connection just in case
    # it invokes a connect()-like method and errors. Once connected, we keep
    # a reference to the instantiated connection and release the provided block
    def __setcon__

      con = @connection_instantiation_block.call
      _makara_decorate_connection(con)

      # release references
      @connection_instantiation_block = nil

      @connection = con

    rescue Exception => e

      # if we're configured to rescue connection failures, we raise a custom error
      # otherwise we blow up
      if @config[:rescue_connection_failures]
        raise ::Makara::Errors::InitialConnectionFailure.new(self, e)
      else
        raise
      end
    end

    # if we've already instantiated a connection, use it. otherwise we need to get connected.
    def __getobj__
      @connection || __setcon__
    end

    # we want to forward all private methods, since we could have kicked out from a private scenario
    def method_missing(method_name, *args, &block)
      super
    rescue NoMethodError => e
      target = __getobj__
      if target.respond_to?(method_name, true)
        target.__send__(method_name, *args, &block)
      else
        raise e
      end
    end


    class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
      def respond_to#{RUBY_VERSION.to_s =~ /^1.8/ ? nil : '_missing'}?(method_name, include_private = false)
        super || __getobj__.respond_to?(method_name, true)
      end
    RUBY_EVAL

    # custom error messages
    def _makara_custom_error_matchers
      @config[:connection_error_matchers] || []
    end


    protected

    # once the underlying connection is present we must evaluate extra functionality into it.
    # all extra functionality is in the format of _makara*
    def _makara_decorate_connection(con)

      extension = %Q{
        # the proxy object controlling this connection
        def _makara
          @_makara
        end

        def _makara=(m)
          @_makara = m
        end

        # if the proxy has already decided the correct connection to use, yield nil.
        # if the proxy has yet to decide, yield the proxy
        def _makara_hijack
          if _makara.hijacked?
            yield nil
          else
            yield _makara
          end
        end

        # for logging, errors, and debugging
        def _makara_name
          #{@config[:name].inspect}
        end
      }

      # Each method the Makara::Proxy needs to hijack should be redefined in the underlying connection.
      # The new definition should allow for the proxy to intercept the invocation if required.
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

      # extend the instance
      con.instance_eval(extension)
      # set the makara context
      con._makara = @proxy

      con._makara
    end

  end
end
