require_relative "boot"
require_relative "../app/middleware/request_logging_middleware"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module WeddingGalleryApi
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])
    config.autoload_paths << Rails.root.join("app/blueprints")
    config.eager_load_paths << Rails.root.join("app/blueprints")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
    config.middleware.insert_after ActionDispatch::RequestId, RequestLoggingMiddleware

    # Background jobs via Solid Queue
    config.active_job.queue_adapter = :solid_queue
  end
end
