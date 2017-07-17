class Kemal::Base
  module DSL
    HTTP_METHODS   = %w(get post put patch delete options)
    FILTER_METHODS = %w(get post put patch delete options all)

    macro included
      # :nodoc:
      DEFAULT_HANDLERS = [] of {String, String, (HTTP::Server::Context -> Nil)}
      # :nodoc:
      WEBSOCKET_HANDLERS = [] of {String, (HTTP::WebSocket, HTTP::Server::Context -> Void)}
      # :nodoc:
      DEFAULT_ERROR_HANDLERS = [] of {Int32, (HTTP::Server::Context, Exception -> Nil)}
      # :nodoc:
      DEFAULT_FILTERS = [] of {Symbol, String, String, (HTTP::Server::Context -> Nil)}
    end

    {% for method in HTTP_METHODS %}
      def {{method.id}}(path, &block : HTTP::Server::Context -> _)
        raise Kemal::Exceptions::InvalidPathStartException.new({{method}}, path) unless Kemal::Utils.path_starts_with_slash?(path)
        route_handler.add_route({{method}}.upcase, path, &block)
      end
    {% end %}

    def ws(path, &block : HTTP::WebSocket, HTTP::Server::Context -> Void)
      raise Kemal::Exceptions::InvalidPathStartException.new("ws", path) unless Kemal::Utils.path_starts_with_slash?(path)
      websocket_handler.add_route path, &block
    end

    def error(status_code, &block : HTTP::Server::Context, Exception -> _)
      add_error_handler status_code, &block
    end

    # All the helper methods available are:
    #  - before_all, before_get, before_post, before_put, before_patch, before_delete, before_options
    #  - after_all, after_get, after_post, after_put, after_patch, after_delete, after_options
    {% for type in ["before", "after"] %}
      {% for method in FILTER_METHODS %}
        def {{type.id}}_{{method.id}}(path = "*", &block : HTTP::Server::Context -> _)
          filter_handler.{{type.id}}({{method}}.upcase, path, &block)
        end
      {% end %}
    {% end %}

    private def initialize_defaults
      DEFAULT_HANDLERS.each do |method, path, block|
        route_handler.add_route(method.upcase, path, &block)
      end

      WEBSOCKET_HANDLERS.each do |path, block|
        ws(path, &block)
      end

      DEFAULT_ERROR_HANDLERS.each do |status_code, block|
        add_error_handler status_code, &block
      end

      DEFAULT_FILTERS.each do |type, method, path, block|
        if type == :before
          filter_handler.before(method, path, &block)
        else
          filter_handler.after(method, path, &block)
        end
      end
    end

    {% for method in HTTP_METHODS %}
      def self.{{method.id}}(path, &block : HTTP::Server::Context -> _)
        DEFAULT_HANDLERS << { {{method}}, path, block }
      end
    {% end %}

    def self.ws(path, &block : HTTP::WebSocket, HTTP::Server::Context -> Void)
      WEBSOCKET_HANDLERS << {path, block}
    end

    def self.error(status_code, &block : HTTP::Server::Context, Exception -> _)
      DEFAULT_ERROR_HANDLERS << {status_code, block}
    end

    # All the helper methods available are:
    #  - before_all, before_get, before_post, before_put, before_patch, before_delete, before_options
    #  - after_all, after_get, after_post, after_put, after_patch, after_delete, after_options
    {% for type in [:before, :after] %}
      {% for method in FILTER_METHODS %}
        def self.{{type.id}}_{{method.id}}(path = "*", &block : HTTP::Server::Context -> _)
          DEFAULT_FILTERS << { {{type}}, {{method}}, path, block }
        end
      {% end %}
    {% end %}
  end
end
