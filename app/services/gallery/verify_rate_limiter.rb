module Gallery
  class VerifyRateLimiter
    MAX_ATTEMPTS = 5
    WINDOW = 10.minutes
    FALLBACK_CACHE = ActiveSupport::Cache::MemoryStore.new

    def initialize(studio_slug:, wedding_slug:, ip:, cache: Rails.cache)
      @studio_slug = studio_slug
      @wedding_slug = wedding_slug
      @ip = ip.presence || "unknown"
      @cache = cache.is_a?(ActiveSupport::Cache::NullStore) ? FALLBACK_CACHE : cache
    end

    def rate_limited?
      @cache.read(cache_key).to_i >= MAX_ATTEMPTS
    end

    def increment_failures!
      attempts = @cache.read(cache_key).to_i + 1
      @cache.write(cache_key, attempts, expires_in: WINDOW)
    end

    def reset!
      @cache.delete(cache_key)
    end

    def retry_after
      WINDOW.to_i
    end

    private

    def cache_key
      [ "gallery-verify", @studio_slug, @wedding_slug, @ip ].join(":")
    end
  end
end
