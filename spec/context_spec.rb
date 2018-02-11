require 'spec_helper'
require 'rack'

describe Makara::Context do
  let(:now) { Time.parse('2018-02-11 11:10:40 +0000') }
  let(:cookie_string) { "mysql:#{now.to_f + 5}|redis:#{now.to_f + 5}" }
  let(:request) { Rack::Request.new({'HTTP_COOKIE' => "_mkra_ctxt=#{cookie_string}"}) }

  before do
    Timecop.freeze(now)
  end

  after do
    Timecop.return
  end

  it 'does not share stickiness state across threads' do
    contexts = {}
    threads = []

    [1, -1].each_with_index do |f, i|
      threads << Thread.new do
        cookie_string = "mysql:#{now.to_f + f*5}"
        request = Rack::Request.new({'HTTP_COOKIE' => "_mkra_ctxt=#{cookie_string}"})

        Makara::Context.init(request)
        contexts["context_#{i}"] = Makara::Context.stuck?('mysql')

        sleep(0.2)
      end
      sleep(0.1)
    end

    threads.map(&:join)
    expect(contexts).to eq({ 'context_0' => true, 'context_1' => false })
  end

  describe 'init' do
    it 'parses stickiness information from cookie string' do
      Makara::Context.init(request)

      expect(Makara::Context.stuck?('mysql')).to be_truthy
      expect(Makara::Context.stuck?('redis')).to be_truthy
      expect(Makara::Context.stuck?('mariadb')).to be_falsey
    end
  end

  describe 'stick' do
    before do
      Makara::Context.init(request)
    end

    it 'sticks a config to master for subsequent requests up to the ttl given' do
      expect(Makara::Context.stuck?('mariadb')).to be_falsey

      Makara::Context.stick('mariadb', 10)

      expect(Makara::Context.stuck?('mariadb')).to be_truthy
      Timecop.travel(now + 20)
      expect(Makara::Context.stuck?('mariadb')).to be_falsey
    end
  end

  describe 'commit' do
    let(:headers) { {} }

    before do
      Makara::Context.init(request)
    end

    it 'does not set a cookie if there is nothing new to stick' do
      Makara::Context.commit(headers)
      expect(headers).to eq({})
    end

    it 'sets the context cookie with updated stickiness and enough max-age' do
      Makara::Context.stick('mariadb', 10)

      Makara::Context.commit(headers)
      expect(headers['Set-Cookie']).to eq("_mkra_ctxt=mysql%3A#{(now + 5).to_f}%7Credis%3A#{(now + 5).to_f}%7Cmariadb%3A#{(now + 10).to_f}; path=/; max-age=11; HttpOnly")
    end
  end
end
