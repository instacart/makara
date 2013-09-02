require 'spec_helper'

# describe Makara2::ConnectionProxy::Mysql2 do

#   before do
#     allow_any_instance_of(Makara2::ConnectionProxy::Mysql2).to receive(:connection_for) do |config|
#       double(:config => config, :query_options => {})
#     end
#   end

#   let(:proxy){ described_class.new(config(1,2)) }

#   it 'should delegate all connect invocations to the underlying connections' do
#     proxy.master_pool.connections.each{|con| expect(con).to receive(:connect).once }
#     proxy.slave_pool.connections.each{|con| expect(con).to receive(:connect).once }

#     proxy.connect
#   end


#   it 'should delegate all close invocations to the underlying connections' do
#     proxy.master_pool.connections.each{|con| expect(con).to receive(:close).once }
#     proxy.slave_pool.connections.each{|con| expect(con).to receive(:close).once }

#     proxy.close
#   end

#   it 'should apply any changes to the query options to the underlying connections' do
#     proxy.query_options.merge! :test => 'thing'
#     proxy.query_options[:other] = 'stuff'

#     proxy.master_pool.connections.each{|con| 
#       expect(con.query_options[:test]).to eq('thing')
#       expect(con.query_options[:other]).to eq('stuff')
#     }
    
#     proxy.slave_pool.connections.each{|con| 
#       expect(con.query_options[:test]).to eq('thing')
#       expect(con.query_options[:other]).to eq('stuff')
#     }
#   end

# end