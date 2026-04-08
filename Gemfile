source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"

# Auth
gem "jwt", "~> 2.7"
gem "bcrypt", "~> 3.1.7"

# Serialization
gem "blueprinter", "~> 1.0"

# Pagination
gem "pagy", "~> 7.0"

# Environment variables
gem "dotenv-rails"

# S3-compatible storage (Cloudflare R2, B2, MinIO, AWS S3)
gem "aws-sdk-s3", "~> 1.0"

# MIME type detection
gem "marcel"

# Image processing & thumbnails
gem "image_processing", "~> 1.2"
gem "ruby-vips"
gem "rubyzip", "~> 2.3"

# Background jobs (Rails 8 built-in)
gem "solid_queue"
gem "solid_cache"
gem "solid_cable"

# CORS
gem "rack-cors"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false

  # Testing
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails"
end
