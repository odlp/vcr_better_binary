require "vcr_better_binary"

require "fileutils"
require "jet_black"
require "jet_black/rspec/matchers"
require "tmpdir"
require "vcr"

RSpec.describe "pruning unused binary data" do
  include JetBlack::RSpec::Matchers

  let(:session) { JetBlack::Session.new }

  before(:each) do
    VCR.configure do |config|
      config.cassette_library_dir = session.directory
    end
  end

  after(:each) do
    FileUtils.rm_rf(session.directory)
  end

  it "removes any binary data not referenced in cassettes" do
    session.create_file "cassette-1.yml", <<~YAML
      http_interactions:
      - request:
          body:
            bin_key: in-use-reference-1
        response:
          body:
            bin_key: in-use-reference-2
    YAML

    session.create_file "cassette-2.yml", <<~YAML
      http_interactions:
      - request:
          body:
            bin_key: in-use-reference-3
        response:
          body:
            bin_key: in-use-reference-4
    YAML

    session.create_file("bin_data/in-use-reference-1", "")
    session.create_file("bin_data/in-use-reference-2", "")
    session.create_file("bin_data/in-use-reference-3", "")
    session.create_file("bin_data/in-use-reference-4", "")
    session.create_file("bin_data/stale-reference-1", "")
    session.create_file("bin_data/stale-reference-2", "")

    VcrBetterBinary::Serializer.new.prune_bin_data

    remaining_data = Dir.glob("bin_data/*", base: session.directory)

    expect(remaining_data).to contain_exactly(
      "bin_data/in-use-reference-1",
      "bin_data/in-use-reference-2",
      "bin_data/in-use-reference-3",
      "bin_data/in-use-reference-4",
    )
  end

  context "in a git repo" do
    context "no cassettes have changed" do
      it "skips pruning to avoid reading all the cassettes" do
        session.create_file("cassette-1.yml", "")
        git_init_and_commit

        cassette_http_bodies = spy("cassette_http_bodies", each_with_object: [])

        VcrBetterBinary::Pruner.new.prune_bin_data(
          bin_data_dir: File.join(session.directory, "/bin_data"),
          cassette_http_bodies: cassette_http_bodies,
        )

        expect(cassette_http_bodies).to_not have_received(:each_with_object)
      end
    end

    context "cassettes have changed" do
      it "performs pruning" do
        session.create_file("cassette-1.yml", "")
        git_init_and_commit
        session.append_to_file("cassette-1.yml", "# edited")

        cassette_http_bodies = spy("cassette_http_bodies", each_with_object: [])

        VcrBetterBinary::Pruner.new.prune_bin_data(
          bin_data_dir: File.join(session.directory, "/bin_data"),
          cassette_http_bodies: cassette_http_bodies,
        )

        expect(cassette_http_bodies).to have_received(:each_with_object)
      end
    end
  end

  private

  def git_init_and_commit
    expect(session.run("git init")).to be_a_success
    expect(session.run("git add .")).to be_a_success
    expect(session.run("git commit -m 'Initial commit'")).to be_a_success
  end
end
