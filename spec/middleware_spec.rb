require 'spec_helper'

describe Makara::Middleware do

  def env_for(path, method = 'get')
    {
      'REQUEST_METHOD' => method.to_s.upcase,
      'PATH_INFO' => path,
      'rack.session' => {},
      'rack.input' => ::StringIO.new('test=true')
    }.merge(@env || {})
  end

  let(:request){ env_for('/get/request') }
  
  let(:responder_app){            lambda{|env| [200, {}, ['Requestor']] }   }
  let(:redirector_app){           lambda{|env| [302, {}, ['Redirector']] }  }


  def middleware(key)
    @middleware ||= {}
    @middleware[key.to_s] ||= Makara::Middleware.new(send("#{key}_app"))
    @middleware[key.to_s]
  end

  def set_cookie_value(headers)
    s = headers['Set-Cookie'].to_s
    s =~ /makara-(.+)?master-ids=(.+)/
    $2 ? $2.to_s.split(';').first : nil
  end

  before do
    connect!(config)
  end

  let(:config){ single_slave_config }

  it "should delete the cookie when a request is made and master is not being used" do
    status, headers, body = middleware('responder').call(request)
    set_cookie_value(headers).should be_nil
  end

  it "should set the cookie to master when a request is made and the master has been stuck to" do
    Makara.stick_id! adapter.id
    status, headers, body = middleware('responder').call(request)
    set_cookie_value(headers).should eql('default')
  end
  
  it "should delete the cookie when a request is made after a sticky request and master is not stuck again" do
    @env = {'HTTP_COOKIE' => 'makara-master-ids=default'}
    status, headers, body = middleware('responder').call(request)
    set_cookie_value(headers).should be_nil
  end

  it "should tell makara to force the id to master" do
    Makara.should_receive(:force_to_master!).with('default').once

    @env = {'HTTP_COOKIE' => 'makara-master-ids=default'}
    status, headers, body = middleware('responder').call(request)
    set_cookie_value(headers).should be_nil
  end

  it "should not unset the cookie when a redirect is encountered and the cookie is present" do
    @env = {'HTTP_COOKIE' => 'makara-master-ids=default'}
    status, headers, body = middleware('redirector').call(request)
    set_cookie_value(headers).should eql('default')
  end

  it 'should stick to individual masters as needed' do
    adapter
    adapter2 = ::ActiveRecord::ConnectionAdapters::MakaraAdapter.new([adapter.mcon], :id => 'secondary')

    adapter.mcon.makara_adapter = adapter

    app = lambda do |env| 
      adapter.execute('update users set value = 1')
      [200, {}, 'Updater']
    end
    
    middle = Makara::Middleware.new(app)

    status, headers, body = middle.call(request)
    set_cookie_value(headers).should eql('default')

    status, headers, body = middle.call(request.merge('HTTP_COOKIE' => 'makara-master-ids=default'))
    set_cookie_value(headers).should be_nil

  end

  context 'with a namespaced config' do
    let(:config){ namespace_config }

    it 'should use the app namespace as the cache key' do
      Makara.namespace.should eql('my_app')

      app = lambda do |env| 
        adapter.execute('update users set value = 1')
        [200, {}, 'Updater']
      end
      
      middle = Makara::Middleware.new(app)

      status, headers, body = middle.call(request)

      headers['Set-Cookie'].should =~ /makara-my_app-master-ids/
      headers['Set-Cookie'].should_not =~ /makara-master-ids/
      
      set_cookie_value(headers).should eql('default')
    end
  end

end