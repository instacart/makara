require 'spec_helper'

describe 'Makara Connection Wrappers' do

  before do
    connect!(config)
  end

  let(:config){ single_slave_config }
  let(:one){ adapter.slave(1) }


  describe '#blacklist!' do

    it 'should schedule the blacklist properly' do
      Delorean.time_travel_to Time.now do
        adapter.master.blacklist!
        adapter.master.instance_variable_get('@blacklisted_until').should be_within(1).of(Time.now)
      end

      Delorean.time_travel_to Time.now do
        one.blacklist!
        one.instance_variable_get('@blacklisted_until').should be_within(1).of(1.minute.from_now)
      end
    end

  end

  describe '#blacklisted?' do

    it 'should return the correct value' do
      one.should_not be_blacklisted
      one.blacklist!
      one.should be_blacklisted
    end

    it 'should reconnect if it\'s served it\'s time' do
      one.connection.should_receive(:reconnect!).once
      one.blacklist!
      Delorean.time_travel_to 70.seconds.from_now do
        one.should_not be_blacklisted
      end
    end

  end

  describe 'Master Wrapper' do

    it 'should know what it is' do
      adapter.master.should be_master
      adapter.master.should_not be_slave
    end

  end

  describe 'Slave Wrapper' do

    it 'should know what it is' do
      one.should_not be_master
      one.should be_slave
    end

    it 'should understand the concept of singularity' do
      one.should be_singular
    end

    context 'with multiple slaves being used' do

      let(:config){ multi_slave_config }
      let(:two){ adapter.slave(2) }

      it 'should not be singular' do
        adapter.slave(1).should_not be_singular
        adapter.slave(2).should_not be_singular
      end

      it 'should construct a singly linked list' do
        one.next_slave.should eql(two)
        two.next_slave.should eql(one)
      end

      describe '#next' do

        it 'should return the next slave if it\'s not blacklisted' do
          one.next.should eql(two)
          two.next.should eql(one)
        end

        it 'should return the next non-blacklisted slave' do
          one.blacklist!
          two.next.should eql(two)
          one.next.should eql(two)
        end

        context 'with a ton of slaves' do

          let(:config){ massive_slave_config  }

          # reversed to make the test more readable
          # the actual linked list is reversed
          let(:two){    adapter.slave(5)      }
          let(:three){  adapter.slave(4)      }
          let(:four){   adapter.slave(3)      }
          let(:five){   adapter.slave(2)      }

          let(:all){ [one, two, three, four, five] }

          after do
            Delorean.back_to_the_present
          end

          it 'should return the next non-blacklisted slave' do

            one.next.should eql(two)
            two.blacklist!
            
            one.next.should eql(three)
            three.next.should eql(four)
            three.blacklist!

            one.next.should eql(four)
            four.blacklist!

            five.next.should eql(one)
            one.blacklist!

            five.next.should eql(five)

          end

          it 'should return nil if all slaves are blacklisted' do
            all.each{|sl| sl.blacklist!         }
            all.each{|sl| sl.next.should be_nil }
          end

          it 'should start using a slave when the blacklisting drops' do
            one.blacklist!

            Delorean.time_travel_to 30.seconds.from_now do
              (all - [one]).each{|sl| sl.blacklist! }
              all.each{|sl| sl.next.should be_nil }
            end

            Delorean.time_travel_to 70.seconds.from_now do
              two.next.should eql(one)
            end

          end
        end 
      end
    end
  end
end