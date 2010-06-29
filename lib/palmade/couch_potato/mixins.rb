module Palmade
  module CouchPotato
    module Mixins
      autoload :CgiAppSession, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/mixins/cgi_app_session')
      autoload :Rails2RequestSession, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/mixins/rails2_request_session')
      autoload :Rails2ActionControllerBase, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/mixins/rails2_action_controller_base')
      autoload :Rails1ActionControllerBase, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/mixins/rails1_action_controller_base')
      autoload :Rails1ActionControllerCgiRequest, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/mixins/rails1_action_controller_cgi_request')
      autoload :SessionUseMemCache, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/mixins/session_use_memcache')
      autoload :SessionUseRedis, File.join(COUCH_POTATO_LIB_DIR, 'couch_potato/mixins/session_use_redis')
    end
  end
end
