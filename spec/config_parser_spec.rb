require 'spec_helper'

describe 'Parsing configuration files' do

  let(:parser){ ::Makara::ConfigParser }
  let(:mock_config) {
    {
      :adapter => 'makara',
      :sticky_slaves => true,
      :host => 'dog',
      :username => 'cat',
      :db_adapter => 'mysql2',
      :databases => [
        {
          :name => 'master',
          :role => 'master'
        },
        {
          :name => 'slave'
        }
      ]
    }
  }


  it 'should iterate through all databases, applying default configs to each' do
    dbs = []
    parser.each_config mock_config do |conf|
      dbs << conf[:name]
      conf[:host].should eql('dog')
      conf[:username].should eql('cat')
      conf[:adapter].should eql('mysql2')
      conf[:sticky_slaves].should be_nil
    end

    dbs.should eql(%w(master slave))
  end

  it 'should extract the master config' do
    master = parser.master_config mock_config

    master.should eql({
      :name => 'master',
      :role => 'master',
      :host => 'dog',
      :username => 'cat',
      :adapter => 'mysql2'
    })
  end

end