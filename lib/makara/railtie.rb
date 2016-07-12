module Makara
  class Railtie < ::Rails::Railtie

    initializer "makara.configure_rails_initialization" do |app|
      app.middleware.use Makara::Middleware
    end

    initializer "makara.initialize_logger" do |app|
      ActiveRecord::LogSubscriber.log_subscribers.each do |subscriber|
        subscriber.extend ::Makara::Logging::Subscriber
      end
    end

  end
end
