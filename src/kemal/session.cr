require "secure_random"

module Kemal
  # Kemal's default session is in-memory only and holds simple String values only.
  # The client-side cookie stores a random ID.
  #
  # Kemal handlers can access the session like so:
  #
  #   get("/") do |env|
  #     env.session["abc"] = "xyz"
  #     uid = env.session["user_id"]?.as(Int32)
  #   end
  #
  # Note that only String values are allowed.
  #
  # Sessions are pruned hourly after 48 hours of inactivity.
  class Sessions
    # Session Types are String, Integer, Float and Boolean
    alias SessionTypes = String | Int32 | Float64 | Bool

    # In-memory, ephemeral datastore only.
    #
    # Implementing Redis or Memcached as a datastore
    # is left as an exercise to another reader.
    #
    # Note that the only thing we store on the client-side
    # is an opaque, random String.  If we actually wanted to
    # store any data, we'd need to implement encryption, key
    # rotation, tamper-detection and that whole iceberg.
    STORE = Hash(String, Session).new

    class Session
      getter! id : String
      property! last_access_at : Int64

      def initialize(@id)
        @last_access_at = Time.new.epoch_ms
        @store = Hash(String, SessionTypes).new
      end

      def [](key : String)
        @last_access_at = Time.now.epoch_ms
        @store[key]
      end

      def []?(key : String)
        @last_access_at = Time.now.epoch_ms
        @store[key]?
      end

      def []=(key : String, value : SessionTypes)
        @last_access_at = Time.now.epoch_ms
        @store[key] = value
      end

      def delete(key : String)
        @last_access_at = Time.now.epoch_ms
        @store.delete(key)
      end
    end

    getter! id : String

    def initialize(ctx : HTTP::Server::Context)
      id = ctx.request.cookies[Kemal.config.session["name"].as(String)]?.try &.value
      if id && id.size == 32
        # valid
      else
        # new or invalid
        id = SecureRandom.hex
      end

      ctx.response.cookies << HTTP::Cookie.new(name: Kemal.config.session["name"].as(String), value: id, http_only: true)
      @id = id
    end

    def []=(key : String, value : SessionTypes)
      store = STORE[id]? || begin
        STORE[id] = Session.new(id)
      end
      store[key] = value
    end

    def [](key : String)
      STORE[@id][key]
    end

    def []?(key : String)
      STORE[@id]?.try &.[key]?
    end

    def delete(key : String)
      STORE[@id]?.try &.delete(key)
    end

    def self.prune!(before = (Time.now - Kemal.config.session["expire_time"].as(Time::Span)).epoch_ms)
      Kemal::Sessions::STORE.delete_if { |id, entry| entry.last_access_at < before }
      nil
    end

    # This is an hourly job to prune the in-memory hash of any
    # sessions which have expired due to inactivity, otherwise
    # we'll have a slow memory leak and possible DDoS vector.
    def self.run_reaper!
      spawn do
        loop do
          prune!
          sleep 3600
        end
      end
    end
  end
end
