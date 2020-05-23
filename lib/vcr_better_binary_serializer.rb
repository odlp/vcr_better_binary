require "digest/bubblebabble"
require "fileutils"
require "vcr_better_binary_serializer/version"
require "vcr_better_binary_serializer/pruner"
require "vcr/cassette/serializers"

class VcrBetterBinarySerializer
  BIN_KEY = "bin_key"

  def initialize(base_serializer: VCR::Cassette::Serializers::YAML)
    @base_serializer = base_serializer
  end

  def file_extension
    base_serializer.file_extension
  end

  def serialize(data)
    yield_http_bodies(data) do |body|
      stash_binary_body_data(body)
    end

    base_serializer.serialize(data)
  end

  def deserialize(string)
    data = base_serializer.deserialize(string)

    yield_http_bodies(data) do |body|
      restore_binary_body_data(body)
    end

    data
  end

  def prune_bin_data
    Pruner.new.prune_bin_data(
      bin_data_dir: bin_data_dir,
      cassette_http_bodies: all_cassette_http_bodies
    )
  end

  private

  attr_reader :base_serializer

  def yield_http_bodies(data)
    data.fetch("http_interactions").each do |interaction|
      request_body = interaction.dig("request", "body")
      yield(request_body) unless request_body.nil?

      response_body = interaction.dig("response", "body")
      yield(response_body) unless response_body.nil?
    end
  end

  def stash_binary_body_data(body)
    return unless body["encoding"] == Encoding::BINARY.name
    return if body["string"].nil? || body["string"].empty?

    bin_key = filename_safe_digest(body["string"])
    bin_storage_path = File.expand_path(bin_key, bin_data_dir)

    write_binary_data(bin_storage_path, body["string"])
    body[BIN_KEY] = bin_key
    body.delete("string")

    bin_key
  end

  def restore_binary_body_data(body)
    return unless body.key?(BIN_KEY)

    bin_storage_path = File.expand_path(body[BIN_KEY], bin_data_dir)
    body["string"] = read_binary_data(bin_storage_path)
    body.delete(BIN_KEY)
  end

  def bin_data_dir
    File.expand_path("bin_data", cassette_dir).tap do |dir|
      FileUtils.mkdir_p(dir)
    end
  end

  def filename_safe_digest(content)
    Digest::SHA256.bubblebabble(content)
  end

  def cassette_dir
    VCR.configuration.cassette_library_dir
  end

  def read_binary_data(path)
    File.open(path, "rb") { |file| file.read }
  end

  def write_binary_data(path, data)
    File.open(path, "wb") { |file| file.write(data) }
  end

  def all_cassette_http_bodies
    Enumerator::Lazy.new(cassette_paths) do |yielder, cassette_path|
      data = base_serializer.deserialize(File.read(cassette_path))

      yield_http_bodies(data) do |body|
        yielder << body
      end
    end
  end

  def cassette_paths
    Dir.glob(File.expand_path("*.#{file_extension}", cassette_dir))
  end
end
