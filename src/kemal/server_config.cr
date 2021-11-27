module Kemal
  module ServerConfig
    {% if flag?(:without_openssl) %}
      property ssl : Bool?
    {% else %}
      property ssl : OpenSSL::SSL::Context::Server?
    {% end %}

    property host_binding = "0.0.0.0"
    property port = 3000
    property env = ENV["KEMAL_ENV"]? || "development"
    property running = false
    property server : HTTP::Server?
    property extra_options : (OptionParser ->)?
    property shutdown_message = true

    def extra_options(&@extra_options : OptionParser ->)
    end
  end
end
