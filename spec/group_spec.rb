require 'spec_helper'

describe 'Makara::ConnectionGroup' do

  before do
    connect!(config)
  end

  let(:config){ single_slave_config }

  it 'should understand the concept of singularity' do
    adapter.master_group.should be_singular
    adapter.slave_group.should be_singular
  end

  context 'with a weighted config' do

    let(:config){ multi_slave_weighted_config }

    it 'should build a wrapper list made up of pointers to the same base connections' do

      adapter.send(:all_wrappers).length.should eql(3)
      adapter.send(:all_connections).length.should eql(3)

      adapter.master_group.should be_singular
      slave_list = adapter.slave_group.wrappers

      slave_list.length.should eql(5)
      slave_list.map(&:object_id).uniq.length.should eql(2)

      slave_list.select{|s| s.name == 'Slave One'}.length.should eql(2)
      slave_list.reject{|s| s.name == 'Slave One'}.length.should eql(3)
    end

  end

  context 'with multiple slaves being used' do

    let(:config){ multi_slave_config  }
    let(:one){    adapter.slave(1)    }
    let(:two){    adapter.slave(2)    }

    it 'should not be singular' do
      adapter.master_group.should be_singular
      adapter.slave_group.should_not be_singular
    end

    describe '#next' do

      let(:group){ adapter.slave_group }

      it 'should return the next slave if it\'s not blacklisted' do
        group.next.should eql(two)
        group.next.should eql(one)
      end

      it 'should return the next non-blacklisted slave' do
        two.blacklist!
        group.next.should eql(one)
        group.next.should eql(one)
      end

      context 'with a ton of slaves' do

        let(:config){ massive_slave_config  }

        let(:three){  adapter.slave(3)      }
        let(:four){   adapter.slave(4)      }
        let(:five){   adapter.slave(5)      }

        let(:all){ [one, two, three, four, five] }

        after do
          Delorean.back_to_the_present
        end

        it 'should return the next non-blacklisted slave' do

          Delorean.time_travel_to Time.now do
            group.next.should eql(two)
            three.blacklist!

            group.next.should eql(four)
            five.blacklist!

            group.next.should eql(one)
            two.blacklist!

            group.next.should eql(four)
            one.blacklist!

            group.next.should eql(four)
            four.blacklist!

            group.next.should be_nil
          end
        end

        it 'should return nil if all slaves are blacklisted' do
          all.each{|sl| sl.blacklist!         }
          group.next.should be_nil
        end

        it 'should start using a slave when the blacklisting drops' do
          one.blacklist!

          Delorean.time_travel_to 30.seconds.from_now do
            (all - [one]).each{|sl| sl.blacklist! }
            group.next.should be_nil
          end

          Delorean.time_travel_to 70.seconds.from_now do
            group.next.should eql(one)
          end

        end

      end
    end
  end
end