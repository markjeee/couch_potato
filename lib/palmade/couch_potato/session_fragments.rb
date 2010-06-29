module Palmade::CouchPotato
  module SessionFragments
    def fkeys
      check_for_fragment!
      fragments.to_a
    end

    def fvalues
      fkeys.collect { |k| fget(k) }.compact
    end

    def fset(key, val, raw = false)
      check_for_fragment!
      fragments.add(key.to_s.freeze)
      handler.cache_set(fkey(key), val, nil, raw)
    end

    def fget(key, raw = false)
      check_for_fragment!
      rawsd = handler.cache_get(fkey(key), raw)
    end

    def ffetch(key, raw = false, &block)
      check_for_fragment!
      handler.cache_fetch(fkey(key), nil, raw, &block)
    end

    def fdelete(key)
      check_for_fragment!
      if fragments.include?(key.to_s)
        fragments.delete(key.to_s)
        handler.cache_delete(fkey(key))
      else
        nil
      end
    end

    def delete_fragments
      fragments.each do |key|
        handler.cache_delete(fkey(key))
      end
    end

    def set_fragment_expiry(ttl = nil, old_sid = nil)
      fragments.each do |key|
        v = handler.cache_get(fkey(key, old_sid), true)
        unless v.nil?
          handler.cache_set(fkey(key), v, ttl, true)
          handler.cache_delete(fkey(key, old_sid)) if old_sid != session_id
        end
      end
    end

    protected

    def check_for_fragment!
      true
    end

    def fkey(key, sid = nil)
      "#{handler.cache_key}/#{sid || session_id}/#{key.to_s.hash}"
    end
  end
end
