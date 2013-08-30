require 'active_record'
require 'makara2'
require 'timecop'
require 'byebug'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.order = 'random'

  require_relative 'support/connection_proxy_extensions'
  require_relative 'support/pool_extensions'
  require_relative 'support/configurator'
  require_relative 'support/mock_objects'
  
  config.include Configurator

  config.before :each do
    Makara2::Cache.store = :memory
    Makara2::Context.set_previous Makara2::Context.generate
    Makara2::Context.set_current Makara2::Context.generate
    allow_any_instance_of(Makara2::Pool).to receive(:should_shuffle?){ false }
  end
end
