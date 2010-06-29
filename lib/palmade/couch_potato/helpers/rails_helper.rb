module Palmade::CouchPotato::Helpers
  module RailsHelper
    def self.setup(configuration, logger)
      Palmade::CouchPotato.logger = logger
      Palmade::CouchPotato.boot!(configuration.root_path)

      # include our thin rails adapter hack for old timers
      if defined?(Rack::Adapter::Rails)
        Rack::Adapter::Rails.class_eval do
          Rack::Adapter::Rails::CgiApp.send(:include, Palmade::CouchPotato::Mixins::CgiAppSession)
        end
      end

      if configuration.frameworks.include?(:action_controller)
        ::ActionController::Base.send(:include, Palmade::CouchPotato::Mixins::Rails1ActionControllerBase)
        ::ActionController::CgiRequest.send(:include, Palmade::CouchPotato::Mixins::Rails1ActionControllerCgiRequest)

        # if we are using couch_potato as the session_store
        if ::ActionController::Base.instance_methods.include?("flash")
          ::ActionController::Base.class_eval do
            def flash_with_couch_potato(*args)
              if session.respond_to?(:flash)
                if defined?(@_flash)
                  @_flash
                else
                  @_flash = session.flash
                end
              else
                flash_without_couch_potato(*args)
              end
            end
            alias_method_chain :flash, :couch_potato
          end
        end
      end
    end
  end
end
