module Makara
  class Railtie < ::Rails::Railtie

    debugger
    
    initializer "makara.configure_rails_initialization" do |app|
      debugger
      app.middleware.use Makara::Middleware
    end

    initializer "makara.initialize_logger" do |app|
      ActiveRecord::LogSubscriber.log_subscribers.each do |subscriber|
        subscriber.extend ::Makara::Logging::Subscriber
      end
    end

  end
end
