module Makara2
  class Railtie < ::Rails::Railtie

    config.app_middleware.use 'Makara2::Middleware'


    initializer "makara2.initialize_logger" do |app|
      ActiveRecord::LogSubscriber.log_subscribers.each do |subscriber|
        subscriber.extend ::Makara2::Logging::Subscriber
      end
    end

  end
end