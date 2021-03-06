require "support/test_server"
require "vcr_better_binary"

require "fileutils"
require "net/http"
require "tmpdir"
require "vcr"
require "webmock"

RSpec.describe "use with VCR" do
  let(:tmp_dir) { Dir.mktmpdir("tmp_vcr_cassettes") }
  let(:image1) { File.expand_path("fixtures/image.png", __dir__) }
  let(:image2) { File.expand_path("fixtures/image.jpg", __dir__) }
  let(:serializer) { VcrBetterBinary::Serializer.new }

  before(:all) do
    @server = TestServer.new(port: 9001)
      .handle("/") do |_, response|
        response.status = 200
        response["Content-Type"] = "image/jpeg"
        response.body = read_binary_data(image2)
      end.start
  end

  after(:all) do
    @server.stop
  end

  before(:each) do
    VCR.configure do |config|
      config.cassette_library_dir = tmp_dir
      config.hook_into :webmock
      config.default_cassette_options = {
        serialize_with: :better_binary,
      }

      silence_warnings do
        # VCR warns about re-registering, but we want a fresh instance per test
        config.cassette_serializers[:better_binary] = serializer
      end
    end
  end

  after(:each) do
    FileUtils.rm_rf(tmp_dir)
  end

  let(:url) { URI("http://localhost:9001") }

  it "persists the cassette without binary data in the request or response" do
    VCR.use_cassette("integration-test") do
      Net::HTTP.post(url, read_binary_data(image1), "Content-Type" => "image/png")
    end

    recorded = YAML.load_file(File.expand_path("integration-test.yml", tmp_dir))
    interaction = recorded["http_interactions"].last

    expect_body_referencing_binary_data(
      body: interaction.dig("request", "body"),
      expected_data: read_binary_data(image1)
    )

    expect_body_referencing_binary_data(
      body: interaction.dig("response", "body"),
      expected_data: read_binary_data(image2)
    )
  end

  it "can be deserialzed successfully" do
    make_request = Proc.new do
      VCR.use_cassette("integration-test-2") do
        Net::HTTP.post(url, read_binary_data(image1), "Content-Type" => "image/png")
      end
    end

    allow(serializer).to receive(:serialize).and_call_original
    allow(serializer).to receive(:deserialize).and_call_original

    responses = 3.times.map { make_request.call.body }

    expect(serializer).to have_received(:serialize).once
    expect(serializer).to have_received(:deserialize).exactly(2).times
    expect(responses).to all eq responses.first
  end

  describe "changing the base serializer" do
    let(:serializer) do
      VcrBetterBinary::Serializer.new(base_serializer: VCR::Cassette::Serializers::JSON)
    end

    it "can be used with different serializers" do
      VCR.use_cassette("integration-test-3") do
        Net::HTTP.post(url, read_binary_data(image1), "Content-Type" => "image/png")
      end

      raw_cassette = File.read(File.expand_path("integration-test-3.json", tmp_dir))
      recorded = JSON.parse(raw_cassette)
      interaction = recorded["http_interactions"].last

      expect(interaction.dig("request", "body")).to have_key("bin_key")
      expect(interaction.dig("response", "body")).to have_key("bin_key")
    end
  end

  private

  def read_binary_data(path)
    data = File.open(path, "rb") { |file| file.read }

    expect(data.encoding).to eq Encoding::BINARY

    data
  end

  def expect_body_referencing_binary_data(body:, expected_data:)
    expect(body["encoding"]).to eq "ASCII-8BIT"
    expect(body).to_not have_key("string")
    expect(body).to have_key("bin_key")

    binary_data_path = File.join(tmp_dir, "/bin_data", body.dig("bin_key"))

    expect(read_binary_data(binary_data_path)).to eq(expected_data)
  end

  def silence_warnings
    original = $stderr
    $stderr = File.new("/dev/null", "w")
    yield
  ensure
    $stderr.close
    $stderr = original
  end
end
