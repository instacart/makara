module Makara
  module Sidekiq
    class Middleware
      def call(*args)
        yield
      ensure
        ::Makara::Context.set_current({})
      end
    end
  end
end
