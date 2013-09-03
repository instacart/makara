module Makara2
  module VERSION

    MAJOR = 0
    MINOR = 2
    PATCH = 0
    PRE = 'beta'

    def self.to_s
      [MAJOR, MINOR, PATCH, PRE].compact.join('.')
    end

  end unless defined?(::Makara2::VERSION)
  ::Makara2::VERSION
end
