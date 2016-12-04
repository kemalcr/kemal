module Kemal
  class SSL
    getter context

    def initialize
      @context = OpenSSL::SSL::Context::Server.new
    end

    def key_file=(key_file)
      @context.private_key = key_file
    end

    def cert_file=(cert_file)
      @context.certificate_chain = cert_file
    end
  end
end
