module Palmade::CouchPotato
  class Pots
    attr_reader :logger
    attr_reader :local
    attr_reader :global

    class << self
      def boot!(config)
        self.pots = new(config)
      end

      def pots
        if defined?(@@pots)
          @@pots
        else
          nil
        end
      end

      def pots=(p); @@pots = p; end
    end

    def initialize(config = { })
      @local = nil
      @global = nil

      @logger = Palmade::CouchPotato.logger
      @config = config

      parse_config!
    end

    def parse_config!
      @local = { "expire_after" => "14400" }
      @global = { "expire_after" => "14400" }

      if @config.include?("local") && !@config["local"].nil?
        @local.merge!(@config["local"])
      end

      if @config.include?("global") && !@config["global"].nil?
        @global.merge!(@config["global"])
      end
    end

    def cache
      Palmade::CouchPotato.sessions_cache
    end
  end
end
