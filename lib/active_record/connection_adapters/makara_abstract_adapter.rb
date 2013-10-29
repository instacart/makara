require 'active_record'

module ActiveRecord
  module ConnectionAdapters
    class MakaraAbstractAdapter < ::Makara::Proxy


      class ErrorHandler < ::Makara::ErrorHandler


        def handle(connection)

          yield

        rescue Exception => e

          # do it via class name to avoid version-specific constant dependencies
          case e.class.name
          when 'ActiveRecord::RecordNotUnique', 'ActiveRecord::InvalidForeignKey'
            harshly(e)
          else
            if connection_message?(e)
              gracefully(connection, e)
            else
              harshly(e)
            end
          end
        end

        protected

        def connection_message?(message)
          message = message.to_s.downcase

          case message
          when /(closed|lost|no)\s?([^\s]+)?\sconnection/, /gone away/
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
        @error_handler = ::ActiveRecord::ConnectionAdapters::MakaraAbstractAdapter::ErrorHandler.new
        super(config)
      end


      protected


      def appropriate_connection(method_name, args)
        if needed_by_all?(method_name, args)

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

          super(method_name, args) do |con|
            yield con
          end

        end
      end


      def should_stick?(method_name, args)
        sql = args.first

        return true if sql.nil?
        return false if sql.to_s =~ /^show\s([\w]+\s)?(field|table|database|schema|view|index)(es|s)?/i
        return false if sql.to_s =~ /^(set|describe|explain|pragma)\s/i
        true
      end

      def needed_by_all?(method_name, args)
        sql = args.first
        return true if sql.to_s =~ SQL_ALL_MATCHER
        false
      end

      def needs_master?(method_name, args)
        sql = args.first
        return false if sql.to_s =~ SQL_SLAVE_MATCHER
        true
      end


    end
  end
end
