require 'active_record'
require 'active_support/all'
require 'makara'
require 'timecop'
require 'yaml'

begin
  require 'byebug'
rescue LoadError
end

begin
  require 'ruby-debug'
rescue LoadError
end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  config.order = 'random'

  require "#{File.dirname(__FILE__)}/support/proxy_extensions"
  require "#{File.dirname(__FILE__)}/support/pool_extensions"
  require "#{File.dirname(__FILE__)}/support/configurator"
  require "#{File.dirname(__FILE__)}/support/mock_objects"
  require "#{File.dirname(__FILE__)}/support/deep_dup"

  config.include Configurator

  config.before :each do
    Makara::Cache.store = :memory
    change_context
    allow_any_instance_of(Makara::Strategies::RoundRobin).to receive(:should_shuffle?){ false }
  end

  def change_context
    Makara::Context.set_previous nil
    Makara::Context.set_current nil
    Makara::Context.clear_stick_to_master_until
  end

  def roll_context
    Makara::Context.set_previous Makara::Context.get_current
    Makara::Context.set_current Makara::Context.generate
  end

end
