module Makara
  class Railtie < Rails::Railtie

    config.app_middleware.use 'Makara::Middleware'

    # This overrides the database connection and reestablishes using makara's list
    initializer "makara.initialize_logger" do |app|
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.logger.try(:extend, ::Makara::Logging::BufferedLoggerDecorator)
      end
    end

  end
end
