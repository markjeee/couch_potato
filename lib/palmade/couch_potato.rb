COUCH_POTATO_LIB_DIR = File.dirname(__FILE__) unless defined?(COUCH_POTATO_LIB_DIR)
COUCH_POTATO_ROOT_DIR = File.join(COUCH_POTATO_LIB_DIR, '../..') unless defined?(COUCH_POTATO_ROOT_DIR)

# >> How to use
#
# add when doing a Rack::Build,
#
# use Palmade::CouchPotato::Session
#
# >> Ideas
#
# * Uses openid to authenticate a new session on another site
# * Has the ability to track child sessions, together with a global session
# * Local sessions can be signed out locally or sign out globally
# * Ability to check session via Javascript (for AJAX apps)
# * Can work with only Rack + Thin (bare minimum)
# * Has a globe expiration settings, from children to parent (synchronized expire)
# * Support for multi-tenanted application (can be based on host:port, or environment vars)
# * Add support for couchdb, basic WWW authentication, as well as HTTPS support

module Palmade
  module CouchPotato
    def self.logger; @logger; end
    def self.logger=(l); @logger = l; end

    autoload :Session, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/session')
    autoload :SessionData, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/session_data')
    autoload :SessionFragments, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/session_fragments')
    autoload :SessionUser, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/session_user')
    autoload :SessionFlash, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/session_flash')
    autoload :Pots, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/pots')
    autoload :Helpers, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/helpers')
    autoload :Mixins, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/mixins')

    def self.boot!(logger, config = { })
      self.logger = logger
      Palmade::CouchPotato::Pots.boot!(config)
    end

    def self.pots
      Palmade::CouchPotato::Pots.pots
    end

    def self.sessions_cache
      if defined?(@@sessions_cache)
        @@sessions_cache
      elsif defined?(Palmade::Cactsing)
        Palmade::Cactsing.cache(sessions_cache_name)
      else
        raise "Sessions cache not defined!"
      end
    end

    def self.sessions_cache=(c)
      @@sessions_cache = c
    end

    def self.sessions_cache_name
      if defined?(@@sessions_cache_name)
        @@sessions_cache_name
      elsif defined?(Palmade::Cactsing)
        Palmade::Cactsing.sessions_cache_name
      else
        "sessions"
      end
    end

    def self.sessions_cache_name=(c)
      @@sessions_cache_name = c
    end
  end
end
