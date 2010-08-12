module Palmade::CouchPotato
  module Mixins
    module SessionUseRedis
      # cache_add("sessions/#{sid}", rawsd, expiry, true)
      def cache_add(k, rawsd, expiry = nil, raw = true)
        rawsd = raw ? rawsd : Marshal.dump(rawsd)
        added = @cache.setnx(k, rawsd)
        if added
          @cache.expire(k, expiry) unless expiry.nil?
        else
          raise CacheCollision, "Session collision on '#{k.inspect}'"
        end

        added
      end

      # cache_set("sessions/#{sid}", rawsd, expiry, true)
      def cache_set(k, rawsd, expiry = nil, raw = true)
        rawsd = raw ? rawsd : Marshal.dump(rawsd)
        @cache.set(k, rawsd)
        @cache.expire(k, expiry) unless expiry.nil?
      end

      # cache_get("sessions/#{sid}", true)
      def cache_get(k, raw = true)
        rawsd = fix_encode(@cache.get(k))
        unless rawsd.nil?
          raw ? rawsd : Marshal.load(rawsd)
        else
          rawsd
        end
      end

      # cache_fetch(x, x)
      def cache_fetch(k, expiry = nil, raw = true, &block)
        value = fix_encode(cache_get(k, raw))

        if value.nil? && block_given?
          value = yield
          cache_add(k, value, expiry, raw)
        end

        value
      end

      # cache_delete("sessions/#{sid}")
      def cache_delete(k)
        @cache.del(k)
      end
    end
  end
end
