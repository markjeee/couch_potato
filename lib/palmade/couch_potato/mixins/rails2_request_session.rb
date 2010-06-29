module Palmade
  module CouchPotato
    module Mixins
      module Rails2RequestSession
        def global_session
          @env['rack.session.global'] ||= { }
        end

        def session_global_options
          @env['rack.session.global.options'] ||= { }
        end

        def reset_session_with_couch_potato
          # let's save the last known session id, so we can delete it!
          unless session_options[:id].nil?
            session_options[:reset] = true
            session_options[:old_id] = session_options[:id]
            session_options[:old_sd] = @env['rack.session']
          end

          session_options.delete(:id)
          @env['rack.session'] = Palmade::CouchPotato::SessionData.new
          @env['rack.session'].global = @env['rack.session.global']

          session
        end

        def reset_global_session
          # let's save the last known session id, so we can delete it!
          unless session_global_options[:id].nil?
            session_global_options[:reset] = true
            session_global_options[:old_id] = session_global_options[:id]
            session_global_options[:old_sd] = @env['rack.session.global']
          end
          session_global_options.delete(:id)

          @env['rack.session.global'] = Palmade::CouchPotato::SessionData.new
          session.global = @env['rack.session.global']

          global_session
        end

        def drop_session
          session_options[:drop] = true
        end

        def drop_global_session
          session_global_options[:drop] = true
        end

        def renew_session
          session_options[:renew] = true
        end

        def renew_global_session
          session_global_options[:renew] = true
        end

        def self.included(base)
          base.class_eval do
            alias_method_chain :reset_session, :couch_potato
          end
        end
      end
    end
  end
end
