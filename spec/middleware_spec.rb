require "spec_helper"

describe Makara::Middleware do
  let(:config){
    base = YAML.load_file(File.expand_path('spec/support/mysql2_database.yml'))['test']
    base
  }

  before do
    ActiveRecord::Base.establish_connection(config)
    # Timecop.travel inside a Timecop.freeze block is safe as it resets time when exiting the block
    Timecop.safe_mode=false
    change_context
  end

  after do
    Timecop.safe_mode=true
  end

  let(:response_object) { double(body: "good_stuff") }
  let(:response_headers) { {'Content-Type' => 'text/plain'} }

  let(:write_to_db) { false }
  let(:time_traveled) { nil }

  let(:app) do
    lambda do |env|
      Timecop.travel(time_traveled) if time_traveled
      connection.execute("insert into users values(1)") rescue nil if write_to_db
      [status, response_headers, response_object]
    end
  end

  let(:env) do
    {
      "REQUEST_METHOD" => request_method,
      "rack.input" => StringIO.new(body),
      "PATH_INFO" => path,
      "QUERY_STRING" => query_string
    }
  end

  let(:request_headers) { {} }

  let(:status) { 324 }
  let(:body) { "yo=1" }
  let(:host) { "some.host" }
  let(:path) { "/some/url" }
  let(:query_string) { "2=1" }

  let(:header_identifier) { Makara::Middleware::HEADER_IDENTIFIER }
  let(:read_header_identifier) { Makara::Middleware::READ_HEADER_IDENTIFIER }
  let(:cookie_identifier) { Makara::Middleware::COOKIE_IDENTIFIER }
  let(:connection) { ActiveRecord::Base.connection }

  let(:ttl) { Makara.master_ttl }
  let(:request_time) { Time.now }
  subject { env.merge!(request_headers); Timecop.freeze(request_time) { Makara::Middleware.new(app).call(env) } }

  def expect_headers_to_be_set(headers, expected_timestamp)
    expect(headers[header_identifier]).to match(/\A[a-f0-9]+--#{status}--#{expected_timestamp}\z/)
    expect(headers["Set-Cookie"]).to match(/\A#{cookie_identifier}=[a-f0-9]+--#{status}--#{expected_timestamp}; path=\/; max-age=#{ttl}; HttpOnly\z/)
  end

  def expect_headers_to_be_nil(headers)
    expect(headers[header_identifier]).to eq nil
    expect(headers["Set-Cookie"]).to eq nil
  end

  shared_examples_for "a middleware that sets makara cookie and header" do
    it "sets makara cookie and header" do
      expect(connection).to receive(:stick_to_master!).at_least(:once).and_call_original # Rollback from DatabaseCleaner triggers it
      status, headers, response_object = subject
      expect_headers_to_be_set(headers, expected_timestamp)
      expect(Makara::Context.stick_to_master_until).to eq nil
    end
  end

  shared_examples_for "a middleware that does not set makara cookie and header" do
    it "does not set makara cookie and header" do
      status, headers, response_object = subject
      expect_headers_to_be_nil(headers)
      expect(Makara::Context.stick_to_master_until).to eq nil
    end
  end

  context 'with a GET request' do
    let(:request_method) { "GET" }

    context "with no cookie nor header" do
      context "when a write happens inside the app" do
        let(:write_to_db) { true }
        let(:expected_timestamp) { request_time.to_i + ttl }
        it_behaves_like "a middleware that sets makara cookie and header"
      end

      context "when no write happens" do
        it_behaves_like "a middleware that does not set makara cookie and header"
      end
    end

    context "with a cookie" do
      before { request_headers["HTTP_COOKIE"] = "#{cookie_identifier}=8172981721901--200--#{timestamp}" }

      context "with a timestamp that is in the past" do
        let(:timestamp) { 5.seconds.ago.to_i }
        it_behaves_like "a middleware that does not set makara cookie and header"
      end

      context "with a timestamp that is in the future" do
        let(:timestamp) { 30.seconds.from_now.to_i }

        context "when the timestamp is done by the end of the query and no new write happened" do
          let(:time_traveled) { 1.minute }
          it_behaves_like "a middleware that does not set makara cookie and header"
        end

        context "when the timestamp is done by the end of the query and a new write happened" do
          let(:write_to_db) { true }
          let(:time_traveled) { 1.minute }
          let(:expected_timestamp) { request_time.to_i + time_traveled + ttl }

          it_behaves_like "a middleware that sets makara cookie and header"
        end

        context "when the timestamp is not done by the end of the query" do
          # Timestamp is way in the future, will set it to the max allowed
          let(:expected_timestamp) { Makara.master_ttl.seconds.from_now.to_i }

          it_behaves_like "a middleware that sets makara cookie and header"
        end
      end
    end

    context "with a header" do
      before { request_headers[read_header_identifier] = "8172981721901--200--#{timestamp}" }

      context "with a timestamp that is in the past" do
        let(:timestamp) { 5.seconds.ago.to_i }
        it_behaves_like "a middleware that does not set makara cookie and header"
      end

      context "with a timestamp that is in the future" do
        let(:timestamp) { 30.seconds.from_now.to_i }
        let(:expected_timestamp) { Makara.master_ttl.seconds.from_now.to_i }
        it_behaves_like "a middleware that sets makara cookie and header"
      end
    end
  end

  context 'with a POST request' do
    let(:request_method) { "POST" }

    it "sticks to master and clears thread caches" do
      expect(Makara).to receive(:stick_to_master!)
      subject
      expect(Makara::Context.stick_to_master_until).to eq nil
    end
  end
end
