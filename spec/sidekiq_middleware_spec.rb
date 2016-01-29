require "spec_helper"

describe Makara::SidekiqMiddleware do
  subject { Makara::SidekiqMiddleware.new.call("SomeKlass", msg, "some_queue") {} }

  let(:msg) { { } }

  it "calls Makara.stick_to_master! while cleaning up at the end" do
    expect(Makara).to receive(:stick_to_master!)
    expect(Makara::Context).to receive(:set_current).with(nil)
    expect(Makara::Context).to receive(:clear_stick_to_master_until)
    subject
  end

  context "when read_from_slave is set" do
    before { msg["read_from_slave"] = true }

    it "does not call Makara.stick_to_master!" do
      expect(Makara).to_not receive(:stick_to_master!)
      subject
    end
  end
end
