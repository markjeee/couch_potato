module Palmade::CouchPotato
  class SessionUser < Struct.new(:user_id)
    class << self
      attr_accessor :serialize_attrs

      def serialize_attr(attr)
        serialize_attrs.add(attr)
      end
    end
    self.serialize_attrs = Set.new

    class << self
      def create_session_user(*args)
        self.new(*args)
      end

      def parse_serialize_ready(sd_ready)
        u = new(sd_ready["user_id"])
        u.instance_eval { @data = sd_ready["data"] }
        u
      end
    end

    def serialize_ready
      { "user_id" => user_id,
        "data" => @data }
    end

    def initialize(*args)
      super(*args)
      @data = { }
    end

    def before_serialize
      self.class.serialize_attrs.each { |attr| @data[attr] = send(attr) } unless self.class.serialize_attrs.nil?
    end

    def after_deserialize
      self.class.serialize_attrs.each { |attr| send("#{attr}=", @data[attr]) } unless self.class.serialize_attrs.nil?
    end

    def [](key)
      @data[key]
    end

    def []=(key, val)
      @data[key] = val
    end

    def keys; @data.keys; end
    def value; @data.values; end
    def size; @data.size; end
    def empty?; @data.empty?; end

    def incremental_merge!(new_user, orig_user = { })
      # delete keys that have been removed on new_sd
      delete_keys = orig_user.keys - new_user.keys
      delete_keys.each { |k| @data.delete(k) } unless delete_keys.empty?

      # update keys that were changed in new_sd, that i know of
      update_keys = new_user.keys.select { |k| new_user[k] != orig_user[k] }
      update_keys.each { |k| @data[k] = new_user[k] } unless update_keys.empty?

      self
    end
  end
end
