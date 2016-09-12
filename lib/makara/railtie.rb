module Makara
  class Railtie < ::Rails::Railtie

    require 'byebug'; byebug

    initializer "makara.configure_rails_initialization" do |app|
      require 'byebug'; byebug
      app.middleware.use Makara::Middleware
    end

    initializer "makara.initialize_logger" do |app|
      require 'byebug'; byebug
      ActiveRecord::LogSubscriber.log_subscribers.each do |subscriber|
        subscriber.extend ::Makara::Logging::Subscriber
      end
    end

  end
end
