return unless ENV["SENTRY_DSN"].present?

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production staging]
  config.environment = ENV.fetch("RAILS_ENV", "development")
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.send_default_pii = false
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.0").to_f
end
