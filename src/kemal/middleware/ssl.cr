module Kemal::Middleware
  # This middleware adds SSL / TLS support.
  class SSL
    getter context

    def initialize
      @context = OpenSSL::SSL::Context::Server.new
    end

    def set_key_file(key_file)
      @context.private_key = key_file
    end

    def set_cert_file(cert_file)
      @context.certificate_chain = cert_file
    end
  end
end
