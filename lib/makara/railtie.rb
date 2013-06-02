module Makara
  class Railtie < Rails::Railtie

    config.app_middleware.use 'Makara::Middleware'

    # This overrides the database connection and reestablishes using makara's list
    initializer "makara.initialize_logger" do |app|
      ActiveRecord::LogSubscriber.log_subscribers.each do |subscriber|
        subscriber.extend ::Makara::Logging::Subscriber
      end
    end

  end
end