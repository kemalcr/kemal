module Kemal
  class Namespace
    # copy form dsl.cr

    HTTP_METHODS   = %w(get post put patch delete options)
    FILTER_METHODS = %w(get post put patch delete options all)

    def self.new(n : String)
      with new(n) yield
    end

    def initialize(@n : String)
    end

    {% for method in HTTP_METHODS %}
      def {{method.id}}(path : String, &block : HTTP::Server::Context -> _)
        ::{{method.id}}(@n + path, &block)
      end
    {% end %}

    def ws(path : String, &block : HTTP::WebSocket, HTTP::Server::Context -> Void)
      ::ws(@n + path, &block)
    end

    # All the helper methods available are:
    #  - before_all, before_get, before_post, before_put, before_patch, before_delete, before_options
    #  - after_all, after_get, after_post, after_put, after_patch, after_delete, after_options
    {% for type in ["before", "after"] %}
      {% for method in FILTER_METHODS %}
        def {{type.id}}_{{method.id}}(path : String = "*", &block : HTTP::Server::Context -> _)
         Kemal::FilterHandler::INSTANCE.{{type.id}}({{method}}.upcase, @n+path, &block)
        end
      {% end %}
    {% end %}

    def namespace(n : String)
      with Kemal::Namespace.new(@n + n) yield
    end
  end
end

def namespace(n : String)
  with Kemal::Namespace.new(n) yield
end
