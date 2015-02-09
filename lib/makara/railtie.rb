module Makara
  class Railtie < ::Rails::Railtie

    initializer "makara.initialize_logger" do |app|
      ActiveRecord::LogSubscriber.log_subscribers.each do |subscriber|
        subscriber.extend ::Makara::Logging::Subscriber
      end
    end

  end
end
