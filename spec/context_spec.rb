require 'spec_helper'

describe Makara::Context do

  describe 'get_current' do
    it 'does not share context acorss threads' do
      uniq_curret_contexts = []
      threads = []

      1.upto(3).map do |i|
        threads << Thread.new do
          current = Makara::Context.get_current
          expect(current).to_not be_nil
          expect(uniq_curret_contexts).to_not include(current)
          uniq_curret_contexts << current

          sleep(0.2)
        end
        sleep(0.1)
      end

      threads.map(&:join)
      expect(uniq_curret_contexts.uniq.count).to eq(3)
    end
  end

  describe 'set_current' do

    it 'does not share context acorss threads' do
      uniq_curret_contexts = []
      threads = []

      1.upto(3).map do |i|
        threads << Thread.new do

          current = Makara::Context.set_current("val#{i}")
          expect(current).to_not be_nil
          expect(current).to eq("val#{i}")

          sleep(0.2)

          current = Makara::Context.get_current
          expect(current).to_not be_nil
          expect(current).to eq("val#{i}")

          uniq_curret_contexts << current
        end
        sleep(0.1)
      end

      threads.map(&:join)
      expect(uniq_curret_contexts.uniq.count).to eq(3)
    end
  end

  describe 'get_previous' do
    it 'does not share context acorss threads' do
      uniq_curret_contexts = []
      threads = []

      1.upto(3).map do |i|
        threads << Thread.new do
          current = Makara::Context.get_previous
          expect(current).to_not be_nil
          expect(uniq_curret_contexts).to_not include(current)
          uniq_curret_contexts << current

          sleep(0.2)
        end
        sleep(0.1)
      end

      threads.map(&:join)
      expect(uniq_curret_contexts.uniq.count).to eq(3)
    end
  end

  describe 'set_previous' do
    it 'does not share context acorss threads' do
      uniq_curret_contexts = []
      threads = []

      1.upto(3).map do |i|
        threads << Thread.new do

          current = Makara::Context.set_previous("val#{i}")
          expect(current).to_not be_nil
          expect(current).to eq("val#{i}")

          sleep(0.2)

          current = Makara::Context.get_previous
          expect(current).to_not be_nil
          expect(current).to eq("val#{i}")

          uniq_curret_contexts << current
        end
        sleep(0.1)
      end

      threads.map(&:join)
      expect(uniq_curret_contexts.uniq.count).to eq(3)
    end

    it 'sets thread local variable makara_cached_previous to nil' do
      t = Thread.current
      t.respond_to?(:thread_variable_set) ? t.thread_variable_set(:makara_cached_previous,1) : t[:makara_cached_previous]=1

      Makara::Context.set_previous("val")

      thread_var = t.respond_to?(:thread_variable_get) ? t.thread_variable_get(:makara_cached_previous) : t[:makara_cached_previous]
      expect(thread_var).to be nil
    end
  end

  describe 'cache_current' do
    it 'caches the current context using Makara::Cache' do
      context = 'some_val'
      config_id = 1
      ttl = 10
      Makara::Cache.store = :memory
      allow(Makara::Context).to receive(:get_current) { context }

      # expect it to not be set yet
      expect(Makara::Cache.read("makara::#{context}-#{config_id}")).to eq(nil)

      Makara::Context.cache_current(config_id, ttl)
      # expect it to be set now
      expect(Makara::Cache.read("makara::#{context}-#{config_id}")).to eq('1')
    end
  end

  describe 'cached_previous?' do
    it 'gets the context that was cached via cache_current' do
      context = 'some_val'
      config_id = 1
      ttl = 10
      Makara::Cache.store = :memory

      # this emulates handling a web request, which gets stuck to master, and therefore stores the current context in cache
      allow(Makara::Context).to receive(:get_current) { context }
      Makara::Context.cache_current(config_id, ttl)

      # this emulates handling a subsequent web request, which included a cookie that is the context from the last request,
      # i.e., now that is considered the "previous" context
      allow(Makara::Context).to receive(:get_previous) { context }
      cached_context =  Makara::Context.cached_previous?(config_id)

      expect(cached_context).to eq(true)
    end
  end
end

