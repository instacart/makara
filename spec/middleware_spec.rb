require 'spec_helper'
require 'time'

describe Makara::Middleware do
  let(:now) { Time.parse('2018-02-11 11:10:40 +0000') }
  let(:app){
    lambda{|env|
      response = proxy.query(env[:query] || 'select * from users')
      [200, {}, response]
    }
  }

  let(:env){ {} }
  let(:proxy){ FakeProxy.new(config(1,2)) }
  let(:middleware){ described_class.new(app, secure: true) }

  let(:key){ Makara::Cookie::IDENTIFIER }

  before do
    @hijacked_methods = FakeProxy.hijack_methods
    FakeProxy.hijack_method :query
    Timecop.freeze(now)
  end

  after do
    Timecop.return
    FakeProxy.hijack_methods = []
    FakeProxy.hijack_method(*@hijacked_methods)
  end

  it 'should init the context and not be stuck by default' do
    _, headers, body = middleware.call(env)

    expect(headers).to eq({})
    expect(body).to eq('replica/1')
  end

  it 'should use the cookie-provided context if present' do
    env['HTTP_COOKIE'] = "#{key}=mock_mysql%3A#{(now + 3).to_f}; path=/; max-age=5"

    _, headers, body = middleware.call(env)

    expect(headers).to eq({})
    expect(body).to eq('primary/1')
  end

  it 'should set the cookie if primary is used' do
    env[:query] = 'update users set name = "phil"'

    _, headers, body = middleware.call(env)

    expect(headers['Set-Cookie']).to eq("#{key}=mock_mysql%3A#{(now + 5).to_f}; path=/; max-age=10; expires=#{(Time.now + 10).httpdate}; secure; HttpOnly")
    expect(body).to eq('primary/1')
  end
end
