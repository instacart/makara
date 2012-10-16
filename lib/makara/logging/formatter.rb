module Makara
  module Logging

    class Formatter < ::Logger::Formatter

      def call(severity, timestamp, progname, msg, &block)

        default = if msg.nil?
         block_given? ? block.call : progname
        else
          "#{msg}\r\n"
        end
          
        return default unless sql_statement?(default)
        return default unless name = wrapper_name
        return "[#{name}] #{default}" unless use_colors?
        
        "#{color_for_wrapper(name)}[#{name}]\e[0m #{default}"
      end

      protected

      def wrapper_name
        Makara.connection.try(:current_wrapper_name)
      end

      def use_colors?
        Makara.connection.try(:ansi_colors?)
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