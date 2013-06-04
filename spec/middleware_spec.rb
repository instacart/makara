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

  let(:get_request){    env_for('/get/request')              }
  let(:post_request){   env_for('/post/request', 'post')     }
  let(:delete_request){ env_for('/delete/request', 'delete') }
  let(:put_request){    env_for('/put/request', 'put')       }

  let(:responder_app){            lambda{|env| [200, {}, ['Requestor']] }   }
  let(:redirector_app){           lambda{|env| [302, {}, ['Redirector']] }  }


  def middleware(key)
    @middleware ||= {}
    @middleware[key.to_s] ||= Makara::Middleware.new(send("#{key}_app"))
    @middleware[key.to_s]
  end

  def set_cookie_value(headers)
    s = headers['Set-Cookie'].to_s
    s =~ /makara-(.+)?master-idxs=(.+)/
    $2 ? $2.to_s.split(';').first : nil
  end

  before do
    connect!(config)
  end

  let(:config){ single_slave_config }

  %w(responder redirector).each do |app|
    %w(get post put delete).each do |req|

      it "should pass through #{req} requests from a #{app} app when the current adapter isn't makara" do
        Makara.stub(:in_use?).and_return(false)
        Makara.should_receive(:with_master).never
        middleware(app).call(send("#{req}_request"))
      end

      it "should delete the cookie when #{req} requests from a #{app} app when master is not being used" do
        adapter.stub(:currently_master?).and_return(false)
        status, headers, body = middleware(app).call(send("#{req}_request"))
        set_cookie_value(headers).should be_nil
      end


      it "should delete the cookie when #{req} requests from a #{app} app when the master is not sticky" do
        adapter.stub(:currently_master?).and_return(false)
        status, headers, body = middleware(app).call(send("#{req}_request"))
        set_cookie_value(headers).should be_nil
      end

      if req == 'get'
        it "should delete the cookie when #{req} requests from a #{app} app and the master is sticky" do
          adapter.stub(:currently_master?).and_return(true)
          adapter.stub(:current_wrapper_name).and_return('master')
          status, headers, body = middleware(app).call(send("#{req}_request"))
          set_cookie_value(headers).should be_nil
        end
      else
        it "should set the cookie to master when #{req} requests from a #{app} app and the master is sticky" do
          adapter.stub(:currently_master?).and_return(true)
          status, headers, body = middleware(app).call(send("#{req}_request"))
          set_cookie_value(headers).should eql('0')
        end
      end

    end
  end

  %w(responder redirector).each do |app|
    %w(get post put delete).each do |req|
      it "should force master if the previous request stuck to master in a #{app} app handling a #{req} request" do
        adapter

        @env = {'HTTP_COOKIE' => 'makara-master-idxs=0'}
        request = send("#{req}_request")
        Makara.should_receive(:with_master).and_return(send("#{app}_app").call(request))
        middleware(app).call(request)
      end

    end
  end

  it "should not unset the cookie when a redirect is encountered and the cookie is present" do
    adapter

    @env = {'HTTP_COOKIE' => 'makara-master-idxs=0'}
    Makara.should_receive(:with_master).and_return(redirector_app.call(get_request))
    middleware('redirector').call(get_request)
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

    status, headers, body = middle.call(post_request)
    set_cookie_value(headers).should eql('0')

    adapter.should_receive(:force_master!).once
    adapter2.should_receive(:force_master!).never

    status, headers, body = middle.call(get_request.merge('HTTP_COOKIE' => 'makara-master-idxs=0'))
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

      status, headers, body = middle.call(post_request)

      headers['Set-Cookie'].should =~ /makara-my_app-master-idxs/
      headers['Set-Cookie'].should_not =~ /makara-master-idxs/
      
      set_cookie_value(headers).should eql('0')
    end
  end

end