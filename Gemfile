source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

gem "bcrypt", "~> 3.1.7"
gem "inertia_rails", "~> 3.6"
gem "vite_rails", "~> 3.0"

gem "faraday", "~> 2.10"
gem "ruby-anthropic", "~> 0.3"

gem "tzinfo-data", platforms: %i[windows jruby]

gem "solid_cache"
gem "solid_queue"

gem "bootsnap", require: false

gem "thruster", require: false

group :development, :test do
  gem "pry"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "dotenv-rails"
  gem "rspec-rails", "~> 8.0"
end

group :test do
  gem "webmock", require: false
end

group :development do
  gem "web-console"
  gem "kamal", require: false
end

gem "langfuse-ruby", "~> 0.1.7"
