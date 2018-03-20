require 'spec_helper'

describe Makara::Cache do

  it 'shows a warning' do
    expect(Makara::Logging::Logger).to receive(:log).with(/Setting the Makara::Cache\.store won't have any effects/, :warn)
    described_class.store = :noop
  end
end
