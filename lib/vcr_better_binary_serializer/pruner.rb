class VcrBetterBinarySerializer
  class Pruner
    def prune_bin_data(bin_data_dir:, cassette_http_bodies:)
      in_use_keys = Set.new

      cassette_http_bodies.each do |http_body|
        if http_body.key?(BIN_KEY)
          in_use_keys << http_body[BIN_KEY]
        end
      end

      Dir.glob(File.expand_path("*", bin_data_dir)).each do |bin_file|
        unless in_use_keys.include?(File.basename(bin_file))
          File.delete(bin_file)
        end
      end
    end
  end
end
