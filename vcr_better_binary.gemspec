require_relative "lib/vcr_better_binary/version"

Gem::Specification.new do |spec|
  spec.name          = "vcr_better_binary"
  spec.version       = VcrBetterBinary::VERSION
  spec.authors       = ["Oliver Peate"]

  spec.summary       = "Persist binary data outside your VCR cassettes"
  spec.homepage      = "https://github.com/odlp/vcr_better_binary"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")

  spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "vcr", "~> 5.0"

  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "jet_black"
  spec.add_development_dependency "rspec_junit_formatter"
end
