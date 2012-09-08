module Makara
  module VERSION

    MAJOR = 0
    MINOR = 0
    PATCH = 1
    PRE = nil

    def self.to_s
      [MAJOR, MINOR, PATCH, PRE].compact.join('.')
    end

  end unless defined?(::Makara::VERSION)
  ::Makara::VERSION
end
