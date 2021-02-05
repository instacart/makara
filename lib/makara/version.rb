# frozen_string_literal: true

module Makara
  module VERSION
    MAJOR = 0
    MINOR = 6
    PATCH = 0
    PRE = "pre"

    def self.to_s
      [MAJOR, MINOR, PATCH, PRE].compact.join('.')
    end
  end unless defined?(::Makara::VERSION)
  ::Makara::VERSION
end
