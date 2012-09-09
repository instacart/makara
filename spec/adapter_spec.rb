require 'spec_helper'

describe ActiveRecord::ConnectionAdapters::MakaraAdapter do

  before do
    connect!(config)
  end

  let(:config){ single_slave_config }

  ActiveRecord::ConnectionAdapters::MakaraAdapter::MASS_DELEGATION_METHODS.each do |meth|
    it "should delegate #{meth} to all connections" do
      adapter.mcon.should_receive(meth).once
      adapter.scon(1).should_receive(meth).once
      adapter.send(meth)
    end
  end

end