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

    it 'sticks a config to master for subsequent requests up to the ttl given' do
      expect(Makara::Context.stuck?('mariadb')).to be_falsey

      Makara::Context.stick('mariadb', 10)

      expect(Makara::Context.stuck?('mariadb')).to be_truthy
      Timecop.travel(now + 20)
      expect(Makara::Context.stuck?('mariadb')).to be_falsey
    end
  end

  describe 'next' do
    before do
      Makara::Context.set_current(context_data)
    end

    it 'returns nil if there is nothing new to stick' do
      expect(Makara::Context.next).to be_nil
    end

    it 'returns hash with updated stickiness' do
      Makara::Context.stick('mariadb', 10)

      next_context = Makara::Context.next
      expect(next_context['mysql']).to eq((now + 5).to_f)
      expect(next_context['redis']).to eq((now + 5).to_f)
      expect(next_context['mariadb']).to eq((now + 10).to_f)
    end

    it 'clears expired entries for configs that are no longer stuck' do
      Timecop.travel(now + 10)

      expect(Makara::Context.next).to eq({})
    end
  end

  describe 'release' do
    before do
      Makara::Context.set_current(context_data)
    end

    it 'clears stickiness for the given config' do
      expect(Makara::Context.stuck?('mysql')).to be_truthy

      Makara::Context.release('mysql')

      expect(Makara::Context.stuck?('mysql')).to be_falsey

      next_context = Makara::Context.next
      expect(next_context.key?('mysql')).to be_falsey
      expect(next_context['redis']).to eq((now + 5).to_f)
    end

    it 'does nothing if the config given was not stuck' do
      expect(Makara::Context.stuck?('mariadb')).to be_falsey

      Makara::Context.release('mariadb')

      expect(Makara::Context.stuck?('mariadb')).to be_falsey
      expect(Makara::Context.next).to be_nil
    end
  end

  describe 'release_all' do
    it 'clears stickiness for all stuck configs' do
      Makara::Context.set_current(context_data)
      expect(Makara::Context.stuck?('mysql')).to be_truthy
      expect(Makara::Context.stuck?('redis')).to be_truthy

      Makara::Context.release_all

      expect(Makara::Context.stuck?('mysql')).to be_falsey
      expect(Makara::Context.stuck?('redis')).to be_falsey
      expect(Makara::Context.next).to eq({})
    end

    it 'does nothing if there were no stuck configs' do
      Makara::Context.set_current({})

      Makara::Context.release_all

      expect(Makara::Context.next).to be_nil
    end
  end
end
