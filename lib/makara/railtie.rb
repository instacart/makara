module Makara
  class Railtie < ::Rails::Railtie

    config.makara = ActiveSupport::OrderedOptions.new # enable namespaced configuration in Rails environments

    initializer "makara.configure" do |app|
      Makara.configure do |config|
        config.skip_middleware = false
        if app.config.makara[:skip_middleware]
          config.skip_middleware = app.config.makara[:skip_middleware] 
        end
      end

      app.config.middleware.insert_before "::Rails::Rack::Logger", "Makara::Middleware"
    end

    initializer "makara.initialize_logger" do |app|
      ActiveRecord::LogSubscriber.log_subscribers.each do |subscriber|
        subscriber.extend ::Makara::Logging::Subscriber
      end
    end

  end
end
