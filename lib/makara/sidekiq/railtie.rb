module Makara
  module Sidekiq
    class Railtie < ::Rails::Railtie
      initializer 'makara-sidekiq.insert_middleware' do |app|
        ::Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Makara::Sidekiq::Middleware
          end
        end
      end
    end
  end
end
