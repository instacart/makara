require 'spec_helper'
require 'redis'

describe Makara::StateCaches do

  before do
    connect!(simple_config)
  end

  it 'provides an interface through the Makara::StateCache class and does not blow up if no spec is present' do
    Makara::StateCache.for(nil, nil).should be_a(Makara::StateCaches::Cookie)
  end

  [
    [:cookie, Makara::StateCaches::Cookie],
    ['Makara::StateCaches::Cookie', Makara::StateCaches::Cookie],
    [nil, Makara::StateCaches::Cookie],
    [:rails, Makara::StateCaches::Rails],
    ['Makara::StateCaches::Rails', Makara::StateCaches::Rails]#,
    # [:redis, Makara::StateCaches::Redis],
    # ['Makara::StateCaches::Redis', Makara::StateCaches::Redis]

  ].each do |input, expectation|

    it "properly retrieves the state cache store via the `for` method when provided with #{input.inspect}" do
      Makara.stub(:primary_config).and_return({:state_cache_store => input})
      Makara::StateCache.for(nil, nil).should be_a(expectation)
    end

  end

  context "cookie store" do

    let(:store){ Makara::StateCaches::Cookie.new(@request, @response) }

    it 'should not do a read if the request is not present' do
      store.get('some-key').should be_nil
    end

    it 'should not do a write if the response is not present' do
      store.set('some-key', 'value', 5).should be_nil
    end

    it 'should not do a delete if the response is not present' do
      store.del('some-key').should be_nil
    end

    it 'should not do a delete unless the Set-Cookie header is present' do
      @response = double(:header => {})
      store.del('some-key')
    end

    it 'should delete a cookie if the Set-Cookie header is present' do
      @response = double(:header => {'Set-Cookie' => 'mycookie!'}, :delete_cookie => 'didit')
      store.del('something').should eql('didit')
    end

    it 'should set a cookie with the correct configuration' do
      t = Time.now
      Time.stub(:now).and_return(t)

      @response = double()
      @response.should_receive(:set_cookie).with('makara-master-idxs', {:value => '0', :path => '/', :expires => Time.now + 5})

      store.set('master-idxs', '0', 5)
    end

    it 'should retrieve a cookie with the correct key' do
      Makara.stub(:namespace).and_return('special-app')

      cookies = double
      @request = double(:cookies => cookies)
      cookies.should_receive(:[]).with('makara-special-app-master-idxs').and_return('0')

      store.get('master-idxs')
    end

  end

  context 'rails cache store' do
    let(:request){ double(:session => {'session_id' => 'abcdefg'})}
    let(:store){ Makara::StateCaches::Rails.new(@request, @response) }

    before do
      cache = double(:read => nil, :write => nil, :delete => nil)
      ::Rails = double() unless defined?(::Rails)
      ::Rails.stub(:cache).and_return(cache)
    end

    it 'converts keys correctly' do
      @request = request
      Makara.stub(:namespace).and_return('my-stuff')
      Rails.cache.should_receive(:read).with('makara-my-stuff-abcdefg-the-key').once
      store.get('the-key')
    end

    it 'does not do anything if no session is present' do
      Rails.cache.should_receive(:read).never
      store.get('the-key')
    end
  end

  context 'redis' do
    let(:request){ double(:session => {'session_id' => 'xyz'})}
    let(:store){ Makara::StateCaches::Redis.new(@request, @response)}

    before do
      Redis.current ||= Redis.new
    end

    it 'should invoke the current configuration if no connection has been supplied' do
      @request = request
      Redis.current.should_receive(:get).with('makara-xyz-the-key').once
      store.get('the-key')
    end

    it 'should use the custom connection if one has been supplied' do
      config = {:host => 'localhost', :port => 6378}
      Makara.stub(:primary_config).and_return({:state_cache_store => :redis, :state_cache => config})
      Makara::StateCaches::Redis.should_receive(:connect).with(config)
      store = Makara::StateCache.for(nil, nil)
    end
  end
end