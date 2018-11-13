module Makara
  class Railtie < ::Rails::Railtie

    initializer "makara.configure_rails_initialization" do |app|
      app.middleware.use Makara::Middleware
    end

  end
end
