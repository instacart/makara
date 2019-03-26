require 'spec_helper'
require 'makara/sidekiq/middleware'

describe Makara::Sidekiq::Middleware do
  let(:worker)  { class_double('Worker') }
  let(:job)     { Hash.new }
  let(:queue)   { 'default' }

  shared_examples 'a cleared context' do
    it 'clears the context' do
      expect(::Makara::Context).to receive(:set_current).with({})

      subject.call(worker, job, queue) {}
    end
  end

  context 'when the worker raises an error' do
    before do
      allow_any_instance_of(worker).to receive(:perform).and_raise(ArgumentError)
    end

    it_behaves_like 'a cleared context'
  end

  context 'when the worker completes successfully' do
    before do
      allow_any_instance_of(worker).to receive(:perform).and_return(true)
    end

    it_behaves_like 'a cleared context'
  end
end
