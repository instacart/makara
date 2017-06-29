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

    it 'clears config sticky cache' do
      Makara::Cache.store = :memory

      Makara::Context.set_previous('a')
      Makara::Context.stick('a', 1, 10)
      expect(Makara::Context.previously_stuck?(1)).to be_truthy

      Makara::Context.set_previous('b')
      expect(Makara::Context.previously_stuck?(1)).to be_falsey
    end
  end

  describe 'stick' do
    it 'sticks a config to master for subsequent requests' do
      Makara::Cache.store = :memory

      expect(Makara::Context.stuck?('context', 1)).to be_falsey

      Makara::Context.stick('context', 1, 10)
      expect(Makara::Context.stuck?('context', 1)).to be_truthy
      expect(Makara::Context.stuck?('context', 2)).to be_falsey
    end
  end

  describe 'previously_stuck?' do
    it 'checks whether a config was stuck to master in the previous context' do
      Makara::Cache.store = :memory
      Makara::Context.set_previous 'previous'

      # Emulate sticking the previous web request to master.
      Makara::Context.stick 'previous', 1, 10

      # Emulate handling the subsequent web request with a previous context
      # cookie that is stuck to master.
      expect(Makara::Context.previously_stuck?(1)).to be_truthy

      # Other configs should not be stuck to master, though.
      expect(Makara::Context.previously_stuck?(2)).to be_falsey
    end
  end
end

