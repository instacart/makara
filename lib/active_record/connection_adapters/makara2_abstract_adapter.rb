module ActiveRecord
  module ConnectionAdapters
    class Makara2AbstractAdapter < ::Makara2::Proxy


      class ErrorHandler < ::Makara2::ErrorHandler


        def handle(connection)
            
          super

        rescue ActiveRecord::RecordNotUnique => e
          harshly(e)
        rescue ActiveRecord::InvalidForeignKey => e
          harshly(e)
        rescue ActiveRecord::StatementInvalid => e
          if connection_message?(e)
            harshly(e)
          else
            gracefully(connection, e)
          end
        end

        protected

        def connection_message?(message)
          message = message.to_s.downcase

          case message
          when /(closed|lost|no)\s?(\w+)? connection/, /gone away/
            true
          else
            false
          end
        end

        
      end



      hijack_method :execute, :select_rows, :exec_query
      send_to_all :connect, :disconnect!, :reconnect!, :verify!, :clear_cache!, :reset!


      SQL_SLAVE_MATCHER       = /^select\s/i
      SQL_ALL_MATCHER         = /^set\s/i


      def initialize(config)
        @error_handler = ::ActiveRecord::ConnectionAdapters::Makara2AbstractAdapter::ErrorHandler.new
        super(config)
      end


      protected


      def appropriate_connection(*args)
        if needed_by_all?(args)
          
          @master_pool.each_connection do |con|
            hijacked do
              yield con
            end
          end
          
          @slave_pool.each_connection do |con|
            hijacked do
              yield con
            end
          end

        else

          super(*args) do |con|
            yield con
          end

        end
      end


      def should_stick?(args)
        sql = args.first
        
        return true if sql.nil?
        return false if sql.to_s =~ /^show\s([\w]+\s)?(field|table|database|schema|view|index)(es|s)?/i
        return false if sql.to_s =~ /^(set|describe|explain|pragma)\s/i
        true
      end

      def needed_by_all?(args)
        sql = args.first
        return true if sql.to_s =~ SQL_ALL_MATCHER
        false
      end

      def needs_master?(args)
        sql = args.first
        return false if sql.to_s =~ SQL_SLAVE_MATCHER
        true
      end


    end
  end
end