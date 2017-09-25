require 'spec_helper'

describe Makara::Cache do

  it 'should not require a store be set' do
    described_class.store = nil

    expect(
      described_class.send(:store)
    ).to be_nil

    expect{
      described_class.read('test')
    }.not_to raise_error
  end

  it 'provides a few stores for testing purposes' do
    described_class.store = :memory
    described_class.write('test', 'value', 10)
    expect(described_class.read('test')).to eq('value')

    described_class.store = :noop
    described_class.write('test', 'value', 10)
    expect(described_class.read('test')).to be_nil
  end


  # this will be used in tests so we have to ensure this works as expected
  context Makara::Cache::MemoryStore do

    let(:store){ Makara::Cache::MemoryStore.new }
    let(:data){ store.instance_variable_get('@data') }

    it 'should read and write keys' do
      expect(store.read('test')).to be_nil
      store.write('test', 'value')
      expect(store.read('test')).to eq('value')
    end

    it 'provides time based expiration' do
      store.write('test', 'value', :expires_in => 5)
      expect(store.read('test')).to eq('value')

      Timecop.travel Time.now + 6 do
        expect(store.read('test')).to be_nil
      end
    end

    it 'cleans the data' do
      store.write('test', 'value', :expires_in => -5)
      expect(store.read('test')).to be_nil
      expect(data).not_to have_key('test')
    end

    it 'has thread-safety' do
      store = Makara::Cache::MemoryStore.new
      previous_value = Thread.abort_on_exception

      begin
        Thread.abort_on_exception = true

        workers = 2.times.map do
          Thread.new do
            100.times do |n|
              store.write(n, 'value', expires_in: 0.5)
              sleep(0.01)
            end
          end
        end

        expect { workers.map(&:join) }.to_not raise_error
      ensure
        Thread.abort_on_exception = previous_value
      end
    end

  end



end
