source 'https://rubygems.org'

gemspec

# only for local testing but not needed for spec tests
group :test do
  gem 'rake'
  gem 'rubocop' if RUBY_VERSION !~ /^1\./
  # rubocop:disable Bundler/DuplicatedGem
  gem 'rubocop', '=0.39.0' if RUBY_VERSION =~ /^1\./
  # rubocop:enable Bundler/DuplicatedGem
end
