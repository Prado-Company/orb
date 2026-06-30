module Foundation
  class CacheAdapter
    DEFAULT_TTL = 5.minutes
    FALLBACK_REASON = "redis fallback without Valkey in dev/test".freeze

    def initialize(redis: nil, namespace: "orb")
      @redis = redis || build_redis
      @namespace = namespace
    rescue StandardError
      @redis = nil
      @memory_fallback = {}
    end

    def fetch(key, ttl: DEFAULT_TTL)
      namespaced = cache_key(key)
      cached = read(namespaced)
      return cached if cached

      value = yield
      write(namespaced, value, ttl: ttl)
      value
    end

    def write(key, value, ttl:)
      raise ArgumentError, "ttl obrigatorio para cache Valkey/Redis" unless ttl

      if @redis
        @redis.set(cache_key(key), value, ex: ttl.to_i)
      else
        memory_fallback[cache_key(key)] = { value: value, expires_at: Time.now + ttl }
      end
    end

    private

    def build_redis
      return nil if Rails.env.test? && ENV["REDIS_URL"].blank?

      Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
    rescue StandardError
      nil
    end

    def read(key)
      return @redis.get(key) if @redis

      entry = memory_fallback[key]
      return unless entry
      return if entry[:expires_at] <= Time.now

      entry[:value]
    end

    def cache_key(key)
      "#{@namespace}:#{key}"
    end

    def memory_fallback
      @memory_fallback ||= {}
    end
  end
end
