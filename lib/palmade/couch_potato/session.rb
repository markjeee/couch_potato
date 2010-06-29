require 'rack'
require 'rack/session/abstract/id'

module Palmade::CouchPotato
  class Session < Rack::Session::Abstract::ID
    class CacheError < StandardError; end
    class UnsupportedCache < StandardError; end
    class CacheCollision < StandardError; end

    CP_DEFAULT_OPTIONS = {
      :cache_key_prefix => nil,
      :session_user => nil,
      :global => nil,
      :sub_domains => false,
      :auto_create => true,
      :cache_expire_after => 3600 # 1 hour
    }

    attr_accessor :global
    alias :global? :global
    def auto_create?; @default_options[:auto_create]; end

    def cache_key
      if defined?(@cache_key)
        @cache_key
      elsif @default_options[:cache_key_prefix].nil?
        @cache_key = global? ? "global_sessions".freeze : "sessions".freeze
      else
        @cache_key = global? ? "global_sessions".freeze :
          "sessions/#{@default_options[:cache_key_prefix]}".freeze
      end
    end

    def initialize(app, options = { })
      super(app, CP_DEFAULT_OPTIONS.merge(options))
      @global = false

      unless @default_options[:global].nil?
        go = @default_options.merge(@default_options.delete(:global))
        @global_session = self.class.new(app, go)
        @global_session.global = true
      else
        @global_session = nil
      end

      @mutex = Mutex.new
    end

    def generate_sid
       Palmade::CouchPotato::SessionData.generate_session_key
    end

    def cache
      if defined?(@cache)
        @cache
      else
        @cache = Palmade::CouchPotato.sessions_cache

        if defined?(MemCache) && @cache.is_a?(MemCache)
          self.extend(Palmade::CouchPotato::Mixins::SessionUseMemCache)
        elsif defined?(DistRedis) && @cache.is_a?(DistRedis)
          self.extend(Palmade::CouchPotato::Mixins::SessionUseRedis)
        else
          raise UnsupportedCache, "Unsupported cache, supports only: memcache | redis"
        end

        @cache
      end
    end

    #
    # The following monkey patches contains some heavy vodooo
    # shit. Please understand, breath, drink some coffee before
    # proceeding to make changes.
    #
    # The following methods modifies the default Rack::Abstract::ID
    # session handler to support the :auto_create option, remembering
    # the session :domain and :path as it was initially created,
    # making it possible to update a session even from different apps
    # or hosts or sub-domains, as long as the browser has exposed that
    # session to us.
    #
    # Ok, that's enough documentation for this area. Go ahead, go read
    # some code.
    #

    def context_with_auto_create(env, app = @app, &block)
      request = Rack::Request.new(env)
      if auto_create? || exist = request.cookies.include?(key)
        if block_given?
          yield(exist)
        else
          context_without_auto_create(env, app)
        end
      else
        app.call(env)
      end
    end
    alias :context_without_auto_create :context
    alias :context :context_with_auto_create

    def context_with_couch_potato(env, app = @app, local_name = nil, &block)
      unless @global_session.nil?
        @global_session.context(env, app, 'global') do
          context_without_couch_potato(env, app)
        end
      else
        if block_given?
          raise "Local name not specified, but needed when working with multiple session keys!" if local_name.nil?

          context_with_auto_create(env, block) do |exist|
            local_env = { }.merge(env)
            load_session(local_env)

            env["rack.session.#{local_name}"] = local_env['rack.session']
            env["rack.session.#{local_name}.options"] = { }.merge(local_env['rack.session.options'])

            status, headers, body = yield

            local_env['rack.session'] = env["rack.session.#{local_name}"]
            local_env['rack.session.options'] = env["rack.session.#{local_name}.options"]

            commit_session(local_env, status, headers, body)
          end
        else
          context_without_couch_potato(env, app)
        end
      end
    end
    alias :context_without_couch_potato :context
    alias :context :context_with_couch_potato

    def load_session_with_couch_potato(env)
      load_session_without_couch_potato(env)

      sd = env['rack.session']
      so = env['rack.session.options']

      # let's set the domain and the path to whatever is set
      # in the session data. for newly created ones, this is
      # just the same as what's set in @default_options[:domain]
      # and @default_options[:path]
      so[:domain] = sd.domain if sd.respond_to?(:domain)
      so[:path] = sd.path if sd.respond_to?(:path)

      if so[:sub_domains] && so[:domain].nil?
        host = (env["HTTP_HOST"] || env["SERVER_NAME"]).to_s.gsub(/:\d+\z/, '')
        so[:domain] = ".#{host}"
        sd.domain = ".#{host}" if sd.respond_to?(:domain)
      end

      so
    end
    alias :load_session_without_couch_potato :load_session
    alias :load_session :load_session_with_couch_potato

    def commit_session_with_couch_potato(env, status, headers, body)
      sd = env['rack.session']
      so = env['rack.session.options']

      # let's set the session data saved domain and path to whatever
      # is set from the session options. this can change on two
      # situations, first (1) is when a new session is created in this
      # request or when the user has explicitly set these data in the]
      # request handling, so we want to update our session data with
      # the updated information
      sd.domain = so[:domain] if sd.respond_to?(:domain)
      sd.path = so[:path] if sd.respond_to?(:path)

      commit_session_without_couch_potato(env, status, headers, body)
    end
    alias :commit_session_without_couch_potato :commit_session
    alias :commit_session :commit_session_with_couch_potato

    def get_session(env, sid)
      # load cache
      cache

      sd = nil
      unless sid.nil?
        sd = get_sd(sid)
      end

      begin
        @mutex.lock if env['rack.multithread']

        if sd.nil?
          env['rack.errors'].puts("Session '#{sid.inspect}' not found, initializing...") if $VERBOSE && !sid.nil?
          sd = Palmade::CouchPotato::SessionData.new(nil, nil, nil, sd_options)

          # let's pre-add it to memcache, our new session
          sid = sd.session_id
          preempt_sid(sid, @default_options[:expire_after] || @default_options[:cache_expire_after])
        end

        # let's set the fragment store, to the same cache store as we came from
        sd.handler = self
        sd.global = env['rack.session.global']

        return [ sid, sd ]
      rescue CacheError, Errno::ECONNREFUSED # MemCache server cannot be contacted
        warn "#{self} is unable to find server. #{sid}"
        warn $!.inspect
        return [ nil, nil ]
      rescue Exception => e
        warn "ERROR: #{e.message}\n#{e.backtrace.join("\n")}"
        raise
      ensure
        @mutex.unlock if env['rack.multithread']
      end
    end

    def set_session(env, sid, sd, options = { })
      cache

      expiry = options[:expire_after] || options[:cache_expire_after]
      expiry += 1 unless expiry.nil?

      begin
        @mutex.lock if env['rack.multithread']
        finalize = nil

        case
        when options[:drop]
          old_sid = sid
          finalize = lambda do
            delete_sd(sd || old_sid)
          end

          sid = "00000000"
        when options[:reset]
          sid = sd.session_id
          preempt_sid(sid, expiry)

          old_sd = options[:old_sd]
          old_sid = options[:old_sid]

          finalize = lambda do
            # we are re-setting
            if !old_sd.nil?
              delete_sd(old_sd)
            elsif !old_sid.nil?
              delete_sd(old_sid)
            end

            sd.increment_revision!
            set_sd(sid, sd, expiry)
          end
        when options[:renew]
          # Add a support for renewing, and still keeping the old session,
          # for up to 5 secs. This prevents almost near concurrent session access
          # to still work, and still be able to hold the old data

          # So, don't delete the old session yet, just re-set expiry to 5 secs
          # and update it with a pointer to the new key
          # move expiry to 5 seconds

          old_sid = sid
          sid = sd.renew_key
          preempt_sid(sid, expiry)

          finalize = lambda do
            incremental_merge(old_sid, sd)

            sd.increment_revision!
            set_sd(sid, sd, expiry, old_sid) # let's save ourselves
            set_sd(old_sid, "renewed\0#{sid}", 5) # let's update the other one, to point to us
          end
        else
          # TODO: when doing an incremental merge, perhaps, there's
          # a better updated since retrieved checking (this seems to be very costly)
          finalize = lambda do
            incremental_merge(sid, sd)

            sd.increment_revision!
            set_sd(sid, sd, expiry)
          end
        end

        unless finalize.nil?
          # let's try to differ this work, after we have sent all response to the client browser
          if defined?(::EventMachine) && EventMachine.reactor_running?
            EventMachine.next_tick(finalize)
          else
            finalize.call
          end
        end

        sid
      rescue CacheError, Errno::ECONNREFUSED # MemCache server cannot be contacted
        warn "#{self} is unable to find server. #{sid}"
        warn $!.inspect
        return false
      rescue Exception => e
        warn "ERROR: #{e.message}\n#{e.backtrace.join("\n")}"
        raise
      ensure
        @mutex.unlock if env['rack.multithread']
      end
    end

    protected

    def incremental_merge(sid, sd)
      # TODO: when doing an incremental merge, perhaps, there's
      # a better updated since retrieved checking (this seems to be very costly)
      saved_sd = get_sd(sid, true)
      unless saved_sd.nil?
        if saved_sd[0].to_i > sd.revision_no
          sd.incremental_merge!(deserialize_rawsd(sid, saved_sd[1]))
        end
      end
    end

    def preempt_sid(sid, expiry = nil)
      add_sd(sid, 0, expiry)
    end

    def add_sd(sid, sd, expiry = nil)
      if sd.is_a?(Palmade::CouchPotato::SessionData)
        rawsd = "#{sd.revision_no}\0#{sd.serialize}"
      elsif sd == 0
        rawsd = "0"
      else
        rawsd = "_#{sd}"
      end

      cache_add("#{cache_key}/#{sid}", rawsd, expiry)
    end

    def set_sd(sid, sd, expiry = nil, old_sid = nil)
      if sd.is_a?(Palmade::CouchPotato::SessionData)
        rawsd = "#{sd.revision_no}\0#{sd.serialize}"
      elsif sd == 0
        rawsd = "0"
      else
        rawsd = "_#{sd}"
      end

      # update fragment expiry
      sd.set_fragment_expiry(expiry, old_sid)

      cache_set("#{cache_key}/#{sid}", rawsd, expiry)
    end

    def get_sd(sid, raw = false)
      rawsd = cache_get("#{cache_key}/#{sid}")
      unless rawsd.nil?
        if rawsd == "0"
          nil
        elsif rawsd[0,1] == '_'
          rawsd = rawsd[1..-1]

          if rawsd.include?("\0")
            status, data = rawsd.split("\0", 2)
            case status
            when "renewed"
              get_sd(data, raw)
            else
              rawsd
            end
          else
            rawsd
          end
        else
          revision_no, rawsd = rawsd.split("\0", 2)
          unless raw
            deserialize_rawsd(sid, rawsd)
          else
            [ revision_no, rawsd ]
          end
        end
      else
        nil
      end
    end

    def deserialize_rawsd(sid, rawsd)
      Palmade::CouchPotato::SessionData.deserialize(sid, rawsd, sd_options)
    end

    def delete_sd(sid)
      if sid.is_a?(Palmade::CouchPotato::SessionData)
        # remove fragments as well
        sid.delete_fragments
        sid = sid.session_id
      end

      cache_delete("#{cache_key}/#{sid}")
    end

    def sd_options
      { :session_user => @default_options[:session_user],
        :path => @default_options[:path],
        :domain => @default_options[:domain] }
    end
  end
end
