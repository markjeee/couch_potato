module Palmade::CouchPotato
  class SessionFlashNow #:nodoc:
    def initialize(flash)
      @flash = flash
    end

    def []=(k, v)
      @flash[k] = v
      @flash.discard(k)
      v
    end

    def [](k)
      @flash[k]
    end
  end

  class SessionFlash < Hash
    attr_reader :used

    def initialize
      super
      @used = Hash.new
    end

    def []=(k, v) #:nodoc:
      keep(k)
      super
    end

    def update(h) #:nodoc:
      h.keys.each { |k| keep(k) }
      super
    end
    alias :merge! :update

    def replace(h) #:nodoc:
      @used = {}
      super
    end

    def now #:nodoc:
      SessionFlashNow.new(self)
    end

    def keep(k = nil) #:nodoc:
      use(k, false)
    end

    def discard(k = nil) #:nodoc:
      use(k)
    end

    def sweep! #:nodoc:
      keys.each do |k|
        unless @used[k]
          use(k)
        else
          delete(k)
          @used.delete(k)
        end
      end

      # clean up after keys that could have been left over by calling reject! or shift on the flash
      (@used.keys - keys).each{ |k| @used.delete(k) }
    end

    def sweep; end # does nothing, to trick Rails that it is sweeping, we do our own sweeping!
    def store(*args); end # does nothing, added for Rails 2 flash compatibility

    private

    def use(k = nil, v = true)
      unless k.nil?
        @used[k] = v
      else
        keys.each{ |key| use(key, v) }
      end
    end
  end
end
