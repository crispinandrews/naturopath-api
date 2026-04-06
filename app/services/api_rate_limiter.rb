require "digest"

class ApiRateLimiter
  Result = Struct.new(:allowed?, :count, :limit, :retry_after, keyword_init: true)

  class << self
    def check(bucket:, discriminator:, limit:, period:)
      cache_key = build_cache_key(bucket: bucket, discriminator: discriminator, period: period)
      count = increment(cache_key, expires_in: period)

      Result.new(
        allowed?: count <= limit,
        count: count,
        limit: limit,
        retry_after: retry_after(period)
      )
    end

    def reset!
      return unless Rails.env.test?

      test_cache_store.clear if test_cache_store
    end

    private

    def build_cache_key(bucket:, discriminator:, period:)
      window = Time.current.to_i / period.to_i
      digest = Digest::SHA256.hexdigest(discriminator.to_s)

      [ "api-rate-limit", bucket, window, digest ].join(":")
    end

    def increment(cache_key, expires_in:)
      count = cache_store.increment(cache_key, 1, expires_in: expires_in)
      return count if count.present?

      cache_store.write(cache_key, 1, expires_in: expires_in)
      1
    end

    def retry_after(period)
      period.to_i - (Time.current.to_i % period.to_i)
    end

    def cache_store
      return Rails.cache unless Rails.cache.is_a?(ActiveSupport::Cache::NullStore)

      self.test_cache_store ||= ActiveSupport::Cache::MemoryStore.new
    end

    attr_writer :test_cache_store

    def test_cache_store
      @test_cache_store
    end
  end
end
