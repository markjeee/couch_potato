module Palmade
  module CouchPotato
    module Mixins
      module CgiAppSession
        def session_options
          ActionController::Base.session_options
        end

        def session_app
          if defined?(@session_app)
            @session_app
          else
            @session_app = Palmade::CouchPotato::Session.new(method(:call_without_couch_potato), session_options)
          end
        end

        def call_with_couch_potato(env)
          session_app.call(env)
        end

        def self.included(base)
          base.class_eval do
            alias :call_without_couch_potato :call
            alias :call :call_with_couch_potato
          end
        end
      end
    end
  end
end
