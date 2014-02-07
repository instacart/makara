require 'spec_helper'

describe Makara::CustomErrors do

  let(:file_path) { File.join(File.expand_path('../', __FILE__), 'support', 'custom_errors.yml') }

  describe "with custom errors loaded" do

    before  { Makara::CustomErrors.load file_path }
    after   { Makara::CustomErrors.clear }

    describe '.custom_error?' do

      it "returns true for a defined custom error" do
        msg = "ActiveRecord::StatementInvalid: Mysql2::Error: Unknown command: SELECT `users`.* FROM `users` WHERE `users`.`id` = 53469 LIMIT 1"
        expect(Makara::CustomErrors.custom_error?(msg)).to be_true
      end

      it "returns false for an error that doesn't match" do
        msg = "Mysql2::Error: Duplicate entry 'coffee-boxing-friday-2-14--7-Task' for key 'index_friendly_id_slugs_on_slug_and_sluggable_type'"
        expect(Makara::CustomErrors.custom_error?(msg)).to be_false
      end

    end

    describe '.should_check?' do

      it "returns true if any custom errors have been loaded" do
        expect(Makara::CustomErrors.should_check?).to be_true
      end

      it "returns false if no custom errors have been loaded" do
        Makara::CustomErrors.clear
        expect(Makara::CustomErrors.should_check?).to be_false
      end

    end

  end

  describe '.load' do

    it "loads custom errors yaml file" do
      expect(Makara::CustomErrors.messages).to eql []
      Makara::CustomErrors.load file_path
      expect(Makara::CustomErrors.messages).to eql [/^ActiveRecord::StatementInvalid: Mysql2::Error: Unknown command:/]
    end

  end

  describe '.clear' do

    it "clears any previously loaded custom errors" do
      Makara::CustomErrors.load file_path
      expect(Makara::CustomErrors.messages).to_not be_empty
      Makara::CustomErrors.clear
      expect(Makara::CustomErrors.messages).to be_empty
    end

  end

end
