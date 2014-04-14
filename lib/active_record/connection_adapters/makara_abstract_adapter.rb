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
          when 'Makara::Errors::BlacklistConnection', 'Makara::Errors::InitialConnectionFailure'
            harshly(e)
          else
            if connection_message?(e) || custom_error_message?(connection, e)
              gracefully(connection, e)
            else
              harshly(e)
            end
          end

        end


        def connection_message?(message)
          message = message.to_s.downcase

          case message
          when /(closed|lost|no|terminating|terminated)\s?([^\s]+)?\sconnection/i, /gone away/i, /connection[^:]+refused/i, /could not connect/i, /connection[^:]+closed/i
            true
          else
            false
          end
        end

        def custom_error_message?(connection, message)
          custom_error_matchers = connection._makara_custom_error_matchers
          return false if !custom_error_matchers || custom_error_matchers.empty?
          
          message = message.to_s

          custom_error_matchers.each do |matcher|
            matcher = /#{matcher}/ if matcher.is_a? String
            return true if message.match matcher
          end

          false
        end


      end



      hijack_method :execute, :select_rows, :exec_query
      send_to_all :connect, :disconnect!, :reconnect!, :verify!, :clear_cache!, :reset!


      SQL_MASTER_MATCHERS     = [/^select.+for update$/i, /select.+lock in share mode$/i]
      SQL_SLAVE_MATCHER       = /^select\s/i
      SQL_ALL_MATCHER         = /^set\s/i
      
      def sql_master_matchers
        SQL_MASTER_MATCHERS
      end
      
      def sql_slave_matcher
        SQL_SLAVE_MATCHER
      end

      def sql_all_matcher
        SQL_ALL_MATCHER
      end

      def initialize(config)
        @error_handler = ::ActiveRecord::ConnectionAdapters::MakaraAbstractAdapter::ErrorHandler.new
        super(config)
      end


      protected

      def send_to_all(method_name, *args)
        handling_an_all_execution do
          super
        end
      end


      def appropriate_connection(method_name, args)
        if needed_by_all?(method_name, args)

          handling_an_all_execution do
            # slave pool must run first.
            @slave_pool.provide_each do |con|
              hijacked do
                yield con
              end
            end

            @master_pool.provide_each do |con|
              hijacked do
                yield con
              end
            end
          end

        else

          super(method_name, args) do |con|
            yield con
          end

        end
      end

      def handling_an_all_execution
        yield
      rescue ::Makara::Errors::NoConnectionsAvailable => e
        raise if e.role == 'master'
        @slave_pool.disabled = true
        yield
      ensure
        @slave_pool.disabled = false
      end


      def should_stick?(method_name, args)
        sql = args.first

        return true if sql.nil?
        return false if sql.to_s =~ /^show\s([\w]+\s)?(field|table|database|schema|view|index)(es|s)?/i
        return false if sql.to_s =~ /^(set|describe|explain|pragma)\s/i
        true
      end

      def needed_by_all?(method_name, args)
        sql = args.first.to_s
        return true if sql =~ sql_all_matcher
        false
      end

      def needs_master?(method_name, args)
        sql = args.first.to_s
        sql_master_matchers.each do |master_regex|
          return true if master_regex =~ sql
        end
        return false if sql =~ sql_slave_matcher
        true
      end

      def connection_for(config)
        active_record_connection_for(config)
      end

      def active_record_connection_for(config)
        raise NotImplementedError
      end


    end
  end
end
