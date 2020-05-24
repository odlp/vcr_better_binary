require "vcr"

module VcrBetterBinary
  class Pruner
    def prune_bin_data(bin_data_dir:, cassette_http_bodies:)
      if in_git_repo? && no_cassette_changes?
        return
      end

      in_use_keys = find_in_use_keys(cassette_http_bodies)

      Dir.glob(File.expand_path("*", bin_data_dir)).each do |bin_file|
        unless in_use_keys.include?(File.basename(bin_file))
          File.delete(bin_file)
        end
      end
    end

    private

    def find_in_use_keys(cassette_http_bodies)
      cassette_http_bodies.each_with_object(Set.new) do |http_body, in_use_keys|
        if http_body.key?(Serializer::BIN_KEY)
          in_use_keys << http_body[Serializer::BIN_KEY]
        end
      end
    end

    def in_git_repo?
      system("git -C '#{cassette_dir}' rev-parse --is-inside-work-tree > /dev/null 2>&1")
    end

    def no_cassette_changes?
      `git -C '#{cassette_dir}' status --porcelain -- '#{cassette_dir}'`.empty?
    end

    def cassette_dir
      VCR.configuration.cassette_library_dir
    end
  end
end
