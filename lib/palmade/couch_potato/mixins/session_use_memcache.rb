module Palmade::CouchPotato
  module Mixins
    module SessionUseMemCache
      # cache_add("sessions/#{sid}", rawsd, expiry, true)
      def cache_add(k, rawsd, expiry, raw = true)
        ret = @cache.add(k, rawsd, expiry || 0, raw)
        raise CacheCollision, "Session collision on '#{k.inspect}'" unless /^STORED/ =~ ret
        ret
      end

      # cache_set("sessions/#{sid}", rawsd, expiry, true)
      def cache_set(k, rawsd, expiry, raw = true)
        @cache.set(k, rawsd, expiry || 0, raw)
      end

      # cache_get("sessions/#{sid}", true)
      def cache_get(k, raw = true)
        @cache.get(k, raw)
      end

      # cache_fetch(x, x)
      def cache_fetch(k, expiry = nil, raw = true, &block)
        value = cache_get(k, raw)

        if value.nil? && block_given?
          value = yield
          cache_add(k, value, expiry, raw)
        end

        value
      end

      # cache_delete("sessions/#{sid}")
      def cache_delete(k)
        @cache.delete(k)
      end
    end
  end
end
