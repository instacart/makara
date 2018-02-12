require 'active_record'
require 'makara'
require 'timecop'
require 'yaml'
require 'rack'

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

  require "#{File.dirname(__FILE__)}/support/helpers"
  require "#{File.dirname(__FILE__)}/support/proxy_extensions"
  require "#{File.dirname(__FILE__)}/support/pool_extensions"
  require "#{File.dirname(__FILE__)}/support/mock_objects"
  require "#{File.dirname(__FILE__)}/support/deep_dup"
  require "#{File.dirname(__FILE__)}/support/user"

  config.include SpecHelpers

  config.before :each do
    change_context
    allow_any_instance_of(Makara::Strategies::RoundRobin).to receive(:should_shuffle?){ false }
    RSpec::Mocks.space.proxy_for(ActiveRecord::Base).reset # make sure not stubbed in some way
  end

  def change_context
    Makara::Context.init(Rack::Request.new({}))
  end
end
