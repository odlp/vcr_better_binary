require "vcr_better_binary_serializer"

require "fileutils"
require "tmpdir"
require "vcr"

RSpec.describe "pruning unused binary data" do
  let(:tmp_dir) { Dir.mktmpdir("tmp_vcr_cassettes") }

  before(:each) do
    VCR.configure do |config|
      config.cassette_library_dir = tmp_dir
    end
  end

  after(:each) do
    FileUtils.rm_rf(tmp_dir)
  end

  it "removes any binary data not referenced in cassettes" do
    File.write tmp_dir_path("cassette-1.yml"), <<~YAML
      http_interactions:
      - request:
          body:
            bin_key: in-use-reference-1
        response:
          body:
            bin_key: in-use-reference-2
    YAML

    File.write tmp_dir_path("cassette-2.yml"), <<~YAML
      http_interactions:
      - request:
          body:
            bin_key: in-use-reference-3
        response:
          body:
            bin_key: in-use-reference-4
    YAML

    FileUtils.mkdir(tmp_dir_path("bin_data"))

    FileUtils.touch([
      tmp_dir_path("bin_data/in-use-reference-1"),
      tmp_dir_path("bin_data/in-use-reference-2"),
      tmp_dir_path("bin_data/in-use-reference-3"),
      tmp_dir_path("bin_data/in-use-reference-4"),
      tmp_dir_path("bin_data/stale-reference-1"),
      tmp_dir_path("bin_data/stale-reference-2"),
    ])

    VcrBetterBinarySerializer.new.prune_bin_data

    remaining_data = Dir.glob("bin_data/*", base: tmp_dir)

    expect(remaining_data).to contain_exactly(
      "bin_data/in-use-reference-1",
      "bin_data/in-use-reference-2",
      "bin_data/in-use-reference-3",
      "bin_data/in-use-reference-4",
    )
  end

  private

  def tmp_dir_path(path)
    File.expand_path(path, tmp_dir)
  end
end
