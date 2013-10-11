require 'spec_helper'

describe Makara::ConfigParser do

  let(:config){
    {
      :top_level => 'value',
      :makara => {
        :connections => [
          {
            :role => 'master',
            :name => 'themaster'
          },
          {
            :name => 'slave1'
          },
          {
            :name => 'slave2'
          }
        ]
      }
    }
  }

  it 'should provide an id based on the recursively sorted config' do
    parsera = described_class.new(config)
    parserb = described_class.new(config.merge(:other => 'value'))
    parserc = described_class.new(config)

    expect(parsera.id).not_to eq(parserb.id)
    expect(parsera.id).to eq(parserc.id)
  end

  it 'should provide master and slave configs' do
    parser = described_class.new(config)
    expect(parser.master_configs).to eq([
      {:name => 'themaster', :top_level => 'value', :blacklist_duration => 30, :master_ttl => 5, :sticky => true}
    ])
    expect(parser.slave_configs).to eq([
      {:name => 'slave1', :top_level => 'value', :blacklist_duration => 30, :master_ttl => 5, :sticky => true},
      {:name => 'slave2', :top_level => 'value', :blacklist_duration => 30, :master_ttl => 5, :sticky => true}
    ])
  end

end
