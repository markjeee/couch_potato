module Palmade::CouchPotato::Helpers
  module Rails2Helper
    def self.setup(configuration)
      Palmade::CouchPotato.logger = Rails.logger
      Palmade::CouchPotato.boot!(configuration.root_path)

      if configuration.frameworks.include?(:action_controller)
        ActionController::Session.const_set("CouchPotato", Palmade::CouchPotato::Session)
        ActionController::Request.send(:include, Palmade::CouchPotato::Mixins::Rails2RequestSession)
        ActionController::Base.send(:include, Palmade::CouchPotato::Mixins::Rails2ActionControllerBase)

        ActionView::Base.class_eval do
          delegate :global_session, :to => :controller
        end

        # if we are using couch_potato as the session_store
        if ActionController::Base.instance_methods.include?("flash")
          ActionController::Base.class_eval do
            def flash_with_couch_potato
              if session.respond_to?(:flash)
                if defined?(@_flash)
                  @_flash
                else
                  @_flash = session.flash
                end
              else
                flash_without_couch_potato
              end
            end
            alias_method_chain :flash, :couch_potato
          end
        end
      end
    end
  end
end
