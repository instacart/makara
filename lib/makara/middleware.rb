module Makara
  class Middleware

    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    ensure
      ActiveRecord::Base.connection.unstick! if ActiveRecord::Base.connection.respond_to?(:unstick!)
    end

  end
end