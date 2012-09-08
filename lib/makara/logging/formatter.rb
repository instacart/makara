module Makara
  module Logging

    class Formatter < ::Logger::Formatter

      def call(severity, timestamp, progname, msg)
        default = "#{msg}\r\n"
        
        return default unless sql_statement?(default)
        return default unless name = wrapper_name

        "#{color_for_wrapper(name)}[#{name}]\e[0m #{default}"
      end

      protected

      def wrapper_name
        return nil unless ActiveRecord::Base.connection.respond_to?(:current_wrapper_name)
        ActiveRecord::Base.connection.try(:current_wrapper_name)
      end

      def sql_statement?(msg)
        !!(msg =~ /(SQL|CACHE|AREL|Load)\s\(/)
      end

      def color_for_wrapper(name)
        # master ? red : yellow
        name =~ /[mM]aster/ ? "\e[31m" : "\e[33m"
      end

    end

  end
end