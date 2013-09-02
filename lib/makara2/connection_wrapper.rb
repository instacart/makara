require 'active_support/core_ext/hash/keys'

module Makara2
  class ConnectionWrapper < ::SimpleDelegator

    def initialize(connection, proxy, config)
      super(connection)

      @config = config.symbolize_keys
      @proxy  = proxy

      _makara_decorate_connection
    end

    def _makara_weight
      @config[:weight] || 1
    end

    def _makara_name
      @config[:name]
    end

    def _makara_blacklisted?
      @blacklisted_until.to_i > Time.now.to_i
    end

    def _makara_blacklist!
      @blacklisted_until = Time.now.to_i + @config[:blacklist_duration]
    end

    protected

    def _makara_decorate_connection
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
      }

      @proxy.class.hijack_methods.each do |meth|
        extension << %Q{
          def #{meth}(*args)
            _makara_hijack do |target|
              if target
                target.#{meth}(*args)
              else
                super
              end
            end
          end
        }
      end

      __getobj__.instance_eval(extension)
      __getobj__._makara = @proxy
    end

  end
end