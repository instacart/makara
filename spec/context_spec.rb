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
  end

end

