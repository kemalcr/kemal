require "http/cookie"
require "base64"
require "json"
require "openssl/hmac"

module Kemal
  class SessionCookieHandler < HTTP::Handler
    property :key, :secret

    INSTANCE = new
    
    def initialize
      @key = "kemal.session"
      @secret = "change_me"
    end

    def self.config
      yield self.instance
    end
   
    def config
      yield self
    end

    def call(context)
      if @secret == "change_me"
        raise ArgumentError.new(<<-MESSAGE
        Please provide a Secret. You may generate one using: 
        crystal eval "require \"secure_random\"; puts SecureRandom.hex(64)"
        MESSAGE
        )
      end
      
      cookies = HTTP::Cookies.from_headers(context.request.headers)
      decode(context.session, cookies[@key].value) if cookies.has_key?(@key)
      call_next(context)
      value = encode(context.session)
      cookies = HTTP::Cookies.from_headers(context.response.headers)
      cookies << HTTP::Cookie.new(@key, value)
      cookies.add_response_headers(context.response.headers)
      context
    end

    def decode (session, data)
      sha1, data = data.split("--", 2)
      if sha1 == OpenSSL::HMAC.hexdigest(:sha1, @secret, data) 
        json = Base64.decode_string(data)
        values = JSON.parse(json)
        values.each do |key, value|
          session[key.to_s] = value.to_s
        end
      end
    end

    def encode (session)
      data = Base64.encode(session.to_json)
      sha1 = OpenSSL::HMAC.hexdigest(:sha1, @secret, data)
      return "#{sha1}--#{data}"
    end
    
  end
end



