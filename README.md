# VCR: Better Binary Serializer

[![CircleCI](https://circleci.com/gh/odlp/vcr_better_binary.svg?style=shield)](https://circleci.com/gh/odlp/vcr_better_binary)

## What

This gem is a [VCR] serializer which persists any binary data in the HTTP
request or response bodies outside the cassette.

[VCR]: https://github.com/vcr/vcr

## Why

- Keeps the cassettes human readable
- You can `git diff` the cassette more easily (and git won't diff the binary
  data stored elsewhere)
- Github won't collapse the diffs for cassettes in PRs (the default for large files)

## How

Add the gem to your `Gemfile` and `bundle install`:

```ruby
group :test do
  gem "vcr_better_binary"
end
```

Configure VCR to use the serializer:

```ruby
# spec/support/vcr.rb (or wherever you configure VCR)

VCR.configure do |config|
  config.cassette_serializers[:better_binary] = VcrBetterBinary::Serializer.new
  config.default_cassette_options = { serialize_with: :better_binary } # or specify inline in 'VCR.use_cassette'
end
```

When you re-record or delete a cassette there may be stale references leftover
in the storage directory.

Add a hook after all your tests have run to prevent unused data from building
up:

```ruby
RSpec.configure do |config|
  config.after(:suite) do
    VcrBetterBinary::Serializer.new.prune_bin_data
  end
end
```

And you're set!

## The end-result

When you record requests with binary data the resulting cassette will
look similar to this:

```yaml
# Abridged example
http_interactions:
- request:
    method: post
    uri: https://example.com/upload
    body:
      encoding: ASCII-8BIT
      bin_key: lymom-vudim-vunek-mobad-fepak-taset-zosyl-zuhaf-setag
  response:
    status:
      code: 200
      message: OK
    body:
      encoding: ASCII-8BIT
      bin_key: xohog-badok-paneg-memek-tahum-degab-kasip-pefik-colol
```

And the following files will have been persisted:

```
spec/fixtures/vcr_cassettes
├── my-cassette.yml
└── bin_data
    ├── lymom-vudim-vunek-mobad-fepak-taset-zosyl-zuhaf-setag
    └── xohog-badok-paneg-memek-tahum-degab-kasip-pefik-colol
```

All remaining VCR functionality will operate as normal; the only adjustment is
the storage of binary data.
