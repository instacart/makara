require 'yaml'

module Makara
  class CustomErrors

    class << self

      def load(file)
        @messages = YAML.load_file(file)['messages']
      end

      def clear
        @messages = nil
      end

      def messages
        @messages || []
      end

      def should_check?
        messages.any?
      end

      def custom_error?(msg)
        msg = msg.to_s

        messages.each do |defined_message|
          return true if msg.match defined_message
        end

        false
      end

    end

  end
end
