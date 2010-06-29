module Palmade::CouchPotato
  class SessionData
    SD_VERSION = 3
    attr_reader :sd_version

    attr_reader :session_key
    alias :session_id :session_key

    attr_reader :user
    attr_reader :user_id
    attr_reader :authenticated
    alias :authenticated? :authenticated
    alias :logged_in? :authenticated

    attr_reader :revision_no
    attr_reader :ips

    # status can be [ :active, :logged_out, :expired, :renewed, :blocked, :destroyed ]
    attr_reader :status
    attr_accessor :path
    attr_accessor :domain

    attr_accessor :handler
    attr_reader :fragments

    attr_reader :secret_key
    alias :secret_id :secret_key

    attr_reader :data
    attr_reader :flash

    attr_accessor :global

    class << self
      def generate_session_key
        Digest::MD5.hexdigest("%04x%04x%04x%06x%06x%s" % [
          rand(0x0010000),
          rand(0x0010000),
          rand(0x0010000),
          rand(0x1000000),
          rand(0x1000000),
          String(Time::now.usec) ])
      end
    end

    def self.deserialize(session_key, blob, options)
      sd = Marshal.load(blob)
      sd = new(session_key, sd, blob, options)
      unless sd.user.nil?
        if sd.user.respond_to?(:after_deserialize)
          sd.user.after_deserialize
        end
      end
      sd
    end

    def serialize
      if !@user.nil? && @user.respond_to?(:before_serialize)
        @user.before_serialize
      end

      Marshal.dump(serialize_ready)
    end

    def initialize(session_key = nil, sd_ready = nil, rawsd = nil, options = { })
      @session_key = session_key || self.class.generate_session_key
      @rawsd = rawsd

      @authenticated = false
      @sd_version = 1

      @ips = Set.new
      @revision_no = 0
      @status = :active

      @user = nil
      @user_id = nil
      @fragments = Set.new
      @secret_key = nil

      @options = options
      @global = nil

      unless sd_ready.nil?
        parse_serialize_ready(sd_ready)
        @flash.sweep!
      else
        @data = Palmade::Smash.new
        @flash = Palmade::CouchPotato::SessionFlash.new
        @path = options[:path]
        @domain = options[:domain]
      end

      # secret_id is another secret key, used internally
      @secret_key = self.class.generate_session_key if @secret_key.nil? || @secret_key.empty?
    end

    def increment_revision!
      @revision_no += 1
    end

    def renew_key
      @session_key = self.class.generate_session_key
    end

    def user=(u)
      if u.is_a?(Palmade::CouchPotato::SessionUser)
        # mark as authenticated
        @authenticated = true

        @user = u
        @user_id = u.user_id
        @user
      elsif u.nil?
        logout!
      else
        raise ArgumentError, "must be a Palmade::CouchPotato::SessionUser object or nil."
      end
    end

    def [](key)
      @data[key]
    end

    def []=(key, val)
      @data[key] = val
    end

    def logout!
      @authenticated = false
      @user = nil
      @user_id = nil
    end

    def incremental_merge!(new_sd)
      if !@rawsd.nil? && new_sd.revision_no > @revision_no
        orig_sd = self.class.deserialize(@session_key, @rawsd, @options)

        # merge ips
        @fragments = (@fragments - orig_sd.fragments) + new_sd.fragments
        @ips = (@ips - orig_sd.ips) + new_sd.ips

        smash_merge(orig_sd.data, new_sd.data, @data)
        smash_merge(orig_sd.flash, new_sd.flash, @flash)
        smash_merge(orig_sd.flash.used, new_sd.flash.used, @flash.used)

        if new_sd.user.nil?
          if orig_sd.user.nil?
            # do nothing!, we were not logged in
          else
            # it means, we were logged out while we're busy
            # so, just log us out as well
            logout!
          end
        else
          if orig_sd.user.nil?
            # we were logged in, somehow
            if @user.nil?
              self.user = new_sd.user
            else
              self.user.incremental_merge!(new_sd.user)
            end
          else
            self.user.incremental_merge!(new_sd.user, orig_sd.user)
          end
        end

        self
      else
        nil
      end
    end

    def smash_merge(old, new, cur)
      # delete keys that have been removed on new_sd
      delete_keys = old.keys - new.keys
      delete_keys.each { |k| cur.delete(k) }

      # update keys that were changed in new_sd
      update_keys = new.keys.select { |k| new[k] != old[k] }
      update_keys.each { |k| cur[k] = new[k] }
    end

    def keys; @data.keys; end
    def values; @data.values; end
    def size; @data.size; end
    def empty; @data.empty?; end
    alias :empty? :empty

    def include?(k); @data.include?(k); end
    alias :has? :include?

    def delete(k); @data.delete(k); end
    alias :remove :delete

    def each(&block)
      @data.each(&block)
    end

    protected

    def serialize_ready
      unless @user.nil?
        if @user.respond_to?(:serialize_ready)
          user_sr = @user.serialize_ready
        else
          user_sr = @user
        end
      else
        user_sr = nil
      end

      sd_ready = { "__sd_version" => @sd_version,
        "revision_no" => @revision_no,
        "authenticated" => @authenticated,
        "data" => @data,
        "flash" => @flash,
        "ips" => @ips,
        "status" => @status,
        "fragments" => @fragments,
        "user_id" => @user_id,
        "user" => user_sr,
        "secret_key" => @secret_key,
        "path" => @path,
        "domain" => @domain }

      sd_ready
    end

    def parse_serialize_ready(sd_ready)
      if sd_ready.is_a?(Hash)
        sdv = sd_ready["__sd_version"]
        if sdv == @sd_version
          @revision_no = sd_ready["revision_no"]
          @authenticated = sd_ready["authenticated"]
          @data = sd_ready["data"]
          @flash = sd_ready["flash"]
          @ips = sd_ready["ips"]
          @fragments = sd_ready["fragments"]
          @status = sd_ready["status"]
          @user_id = sd_ready["user_id"]
          @secret_key = sd_ready["secret_key"]
          @path = sd_ready["path"]
          @domain = sd_ready["domain"]

          unless sd_ready["user"].nil? || @options[:session_user].nil?
            @user = @options[:session_user].parse_serialize_ready(sd_ready["user"])
          else
            @user = sd_ready["user"]
          end
        else
          raise "Incompatible session data on store now: #{sdv}"
        end
      else
        raise "Incompatible session format on store now: #{sd_ready.class.name}"
      end
    end

    include Palmade::CouchPotato::SessionFragments
  end
end
