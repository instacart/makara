require 'spec_helper'
require 'rack'
require 'time'

describe Makara::Context do
  let(:now) { Time.parse('2018-02-11 11:10:40 +0000') }
  let(:context_data) { { "mysql" => now.to_f + 5, "redis" => now.to_f + 5 } }

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
        context_data = { "mysql" => now.to_f + f*5 }
        Makara::Context.set_current(context_data)

        contexts["context_#{i}"] = Makara::Context.stuck?('mysql')

        sleep(0.2)
      end
      sleep(0.1)
    end

    threads.map(&:join)
    expect(contexts).to eq({ 'context_0' => true, 'context_1' => false })
  end

  describe 'set_current' do
    it 'sets stickiness information from given hash' do
      Makara::Context.set_current(context_data)

      expect(Makara::Context.stuck?('mysql')).to be_truthy
      expect(Makara::Context.stuck?('redis')).to be_truthy
      expect(Makara::Context.stuck?('mariadb')).to be_falsey
    end
  end

  describe 'stick' do
    before do
      Makara::Context.set_current(context_data)
    end

    it 'sticks a proxy to primary for the current request' do
      expect(Makara::Context.stuck?('mariadb')).to be_falsey

      Makara::Context.stick('mariadb', 10)

      expect(Makara::Context.stuck?('mariadb')).to be_truthy
      Timecop.travel(Time.now + 20)
      # The ttl kicks off when the context is committed
      next_context = Makara::Context.next
      expect(next_context['mariadb']).to be >= now.to_f + 30 # 10 ttl + 20 seconds that have passed

      # It expires after going to the next request
      Timecop.travel(Time.now + 20)
      Makara::Context.next
      expect(Makara::Context.stuck?('mariadb')).to be_falsey
    end

    it "doesn't overwrite previously stuck proxies with current-request-only stickiness" do
      expect(Makara::Context.stuck?('mysql')).to be_truthy

      # ttl=0 to avoid persisting mysql for the next request
      Makara::Context.stick('mysql', 0)

      Makara::Context.next
      # mysql proxy is still stuck in the next context
      expect(Makara::Context.stuck?('mysql')).to be_truthy
    end

    it 'uses always the max ttl given' do
      expect(Makara::Context.stuck?('mariadb')).to be_falsey

      Makara::Context.stick('mariadb', 10)
      expect(Makara::Context.stuck?('mariadb')).to be_truthy

      Makara::Context.stick('mariadb', 5)

      next_context = Makara::Context.next
      expect(next_context['mariadb']).to eq((now + 10).to_f)
    end

    it 'supports floats as ttl' do
      expect(Makara::Context.stuck?('mariadb')).to be_falsey

      Makara::Context.stick('mariadb', 0.5)

      next_context = Makara::Context.next
      expect(next_context['mariadb']).to eq((now + 0.5).to_f)
    end
  end

  describe 'next' do
    before do
      Makara::Context.set_current(context_data)
    end

    it 'returns nil if there is nothing new to stick' do
      expect(Makara::Context.next).to be_nil
    end

    it "doesn't store staged proxies with 0 stickiness duration" do
      Makara::Context.stick('mariadb', 0)

      expect(Makara::Context.next).to be_nil
    end

    it 'returns hash with updated stickiness' do
      Makara::Context.stick('mariadb', 10)

      next_context = Makara::Context.next
      expect(next_context['mysql']).to eq((now + 5).to_f)
      expect(next_context['redis']).to eq((now + 5).to_f)
      expect(next_context['mariadb']).to eq((now + 10).to_f)
    end

    it "doesn't update previously stored proxies if the update will cause a sooner expiration" do
      Makara::Context.stick('mariadb', 10)
      Makara::Context.stick('mysql', 2.5)

      next_context = Makara::Context.next
      expect(next_context['mysql']).to eq((now + 5).to_f)
      expect(next_context['mariadb']).to eq((now + 10).to_f)

      Makara::Context.set_current(context_data)
      Makara::Context.stick('mysql', 2.5)

      expect(Makara::Context.next).to be_nil
    end

    it 'clears expired entries for proxies that are no longer stuck' do
      Timecop.travel(now + 10)

      expect(Makara::Context.next).to eq({})
    end

    it 'sets expiration time with ttl based on the invokation time' do
      Makara::Context.stick('mariadb', 10)
      request_ends_at = Time.now + 20
      Timecop.travel(request_ends_at)

      next_context = Makara::Context.next

      # The previous stuck proxies would have expired
      expect(next_context['mysql']).to be_nil
      expect(next_context['redis']).to be_nil
      # But the proxy stuck in that request would expire in ttl seconds from now
      expect(next_context['mariadb']).to be >= (request_ends_at + 10).to_f
    end
  end

  describe 'release' do
    before do
      Makara::Context.set_current(context_data)
    end

    it 'clears stickiness for the given proxy' do
      expect(Makara::Context.stuck?('mysql')).to be_truthy

      Makara::Context.release('mysql')

      expect(Makara::Context.stuck?('mysql')).to be_falsey

      next_context = Makara::Context.next
      expect(next_context.key?('mysql')).to be_falsey
      expect(next_context['redis']).to eq((now + 5).to_f)
    end

    it 'does nothing if the proxy given was not stuck' do
      expect(Makara::Context.stuck?('mariadb')).to be_falsey

      Makara::Context.release('mariadb')

      expect(Makara::Context.stuck?('mariadb')).to be_falsey
      expect(Makara::Context.next).to be_nil
    end
  end

  describe 'release_all' do
    it 'clears stickiness for all stuck proxies' do
      Makara::Context.set_current(context_data)
      expect(Makara::Context.stuck?('mysql')).to be_truthy
      expect(Makara::Context.stuck?('redis')).to be_truthy

      Makara::Context.release_all

      expect(Makara::Context.stuck?('mysql')).to be_falsey
      expect(Makara::Context.stuck?('redis')).to be_falsey
      expect(Makara::Context.next).to eq({})
    end

    it 'does nothing if there were no stuck proxies' do
      Makara::Context.set_current({})

      Makara::Context.release_all

      expect(Makara::Context.next).to be_nil
    end
  end
end
