require 'spec_helper'
require 'rack'
require 'time'

describe Makara::Context do
  let(:now) { Time.parse('2018-02-11 11:10:40 +0000') }
  let(:cookie_string) { "mysql:#{now.to_f + 5}|redis:#{now.to_f + 5}" }
  let(:cookie_key) { Makara::Cookie::IDENTIFIER }
  let(:request) { Rack::Request.new({'HTTP_COOKIE' => "#{cookie_key}=#{cookie_string}"}) }

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
        request = Rack::Request.new({'HTTP_COOKIE' => "#{cookie_key}=#{cookie_string}"})

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
      expect(headers['Set-Cookie']).to include("#{cookie_key}=mysql%3A#{(now + 5).to_f}%7Credis%3A#{(now + 5).to_f}%7Cmariadb%3A#{(now + 10).to_f};")
      expect(headers['Set-Cookie']).to include("path=/; max-age=15; expires=#{(Time.now + 15).gmtime.rfc2822}; HttpOnly")
    end

    it 'clears expired entries for configs that are no longer stuck' do
      Timecop.travel(now + 10)

      Makara::Context.commit(headers)
      expect(headers['Set-Cookie']).to eq("#{cookie_key}=; path=/; max-age=0; expires=#{Time.now.gmtime.rfc2822}; HttpOnly")
    end

    it 'allows custom cookie options to be provided' do
      Makara::Context.stick('mariadb', 10)

      Makara::Context.commit(headers, { :secure => true })
      expect(headers['Set-Cookie']).to include("path=/; max-age=15; expires=#{(Time.now + 15).gmtime.rfc2822}; secure; HttpOnly")
    end
  end

  describe 'release' do
    let(:headers) { {} }

    before do
      Makara::Context.init(request)
    end

    it 'clears stickiness for the given config' do
      Makara::Context.release('mysql')

      Makara::Context.commit(headers)
      expect(headers['Set-Cookie']).to eq("#{cookie_key}=redis%3A#{(now + 5).to_f}; path=/; max-age=10; expires=#{(Time.now + 10).gmtime.rfc2822}; HttpOnly")
    end

    it 'does nothing if the config given was not stuck' do
      Makara::Context.release('mariadb')

      Makara::Context.commit(headers)
      expect(headers).to eq({})
    end
  end

  describe 'release_all' do
    let(:headers) { {} }

    it 'clears stickiness for all stuck configs' do
      Makara::Context.init(request)
      Makara::Context.release_all

      Makara::Context.commit(headers)
      expect(headers['Set-Cookie']).to eq("#{cookie_key}=; path=/; max-age=0; expires=#{Time.now.gmtime.rfc2822}; HttpOnly")
    end

    it 'does nothing if there were no stuck configs' do
      Makara::Context.init(Rack::Request.new({}))
      Makara::Context.release_all

      Makara::Context.commit(headers)
      expect(headers).to eq({})
    end
  end
end
