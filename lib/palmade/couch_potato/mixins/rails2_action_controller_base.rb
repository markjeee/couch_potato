module Palmade
  module CouchPotato
    module Mixins
      module Rails2ActionControllerBase
        def global_session
          request.global_session
        end

        def reset_global_session
          request.reset_global_session
        end

        def drop_session
          request.drop_session
        end

        def drop_global_session
          request.drop_global_session
        end

        def reset_session_for_user(su)
          reset_session
          session.user = su
          session
        end
      end
    end
  end
end
