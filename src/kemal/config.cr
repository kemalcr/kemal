module Kemal
  # Stores all the configuration options for a Kemal application.
  # It's a singleton and you can access it like.
  #
  # ```
  # Kemal.config
  # ```
  class Config
    property host_binding = "0.0.0.0"
    property port = 3000
    {% if flag?(:without_openssl) %}
    property ssl : Bool?
    {% else %}
    property ssl : OpenSSL::SSL::Context::Server?
    {% end %}
    property env = "development"
    property serve_static : Hash(String, Bool) | Bool = {"dir_listing" => false, "gzip" => true}
    property public_folder = "./public"
    property? logging = true
    property? always_rescue = true
    property? shutdown_message = true
    property extra_options : (OptionParser ->)?
    property static_headers : (HTTP::Server::Response, String, File::Stat -> Void)?


    # Creates a config with default values.
    def initialize(
                   @host_binding = "0.0.0.0",
                   @port = 3000,
                   @ssl = nil,
                   @env = "development",
                   @serve_static = {"dir_listing" => false, "gzip" => true},
                   @public_folder = "./public",
                   @logging = true,
                   @always_rescue = true,
                   @shutdown_message = true,
                   @extra_options = nil,
                   static_headers = nil)
    end

    def scheme
      ssl ? "https" : "http"
    end

    def extra_options(&@extra_options : OptionParser ->)
    end

    def serve_static?(key)
      config = @serve_static
      (config.is_a?(Hash) && config[key]?) || false
    end


    def extra_options(&@extra_options : OptionParser ->)
    end
  end
end
