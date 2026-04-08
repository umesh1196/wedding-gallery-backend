module Gallery
  class CommentRateLimiter
    MAX_ATTEMPTS = 5
    WINDOW = 10.minutes
    FALLBACK_CACHE = ActiveSupport::Cache::MemoryStore.new

    def initialize(wedding:, gallery_session:, ip:, cache: Rails.cache)
      @wedding = wedding
      @gallery_session = gallery_session
      @ip = ip.presence || "unknown"
      @cache = cache.is_a?(ActiveSupport::Cache::NullStore) ? FALLBACK_CACHE : cache
    end

    def allowed?
      @cache.read(cache_key).to_i < MAX_ATTEMPTS
    end

    def record!
      attempts = @cache.read(cache_key).to_i + 1
      @cache.write(cache_key, attempts, expires_in: WINDOW)
    end

    def retry_after
      WINDOW.to_i
    end

    private

    def cache_key
      [ "gallery-comments", @wedding.id, @gallery_session.id, @ip ].join(":")
    end
  end
end
