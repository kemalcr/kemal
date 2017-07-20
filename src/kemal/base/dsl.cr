class Kemal::Base
  private CUSTOM_METHODS_REGISTRY = {} of _ => _

  macro inherited
    {% CUSTOM_METHODS_REGISTRY[@type] = {
         handlers: [] of _,
         ws:       [] of _,
         error:    [] of _,
         filters:  [] of _,
       } %}

    include MacroDSL
  end

  module DSL
    HTTP_METHODS   = %w(get post put patch delete options)
    FILTER_METHODS = %w(get post put patch delete options all)

    {% for method in HTTP_METHODS %}
      # Add a `{{method.id.upcase}}` handler.
      #
      # The block receives an `HTTP::Server::Context` as argument.
      def {{method.id}}(path, &block : HTTP::Server::Context -> _)
        raise Kemal::Exceptions::InvalidPathStartException.new({{method}}, path) unless path.starts_with?("/")
        route_handler.add_route({{method}}.upcase, path, &block)
      end
    {% end %}

    # Add a webservice handler.
    #
    # The block receives `HTTP::WebSocket` and `HTTP::Server::Context` as arguments.
    def ws(path, &block : HTTP::WebSocket, HTTP::Server::Context -> Void)
      raise Kemal::Exceptions::InvalidPathStartException.new("ws", path) unless path.starts_with?("/")
      websocket_handler.add_route path, &block
    end

    # Add an error handler for *status_code*.
    #
    # The block receives `HTTP::Server::Context` and `Exception` as arguments.
    def error(status_code, &block : HTTP::Server::Context, Exception -> _)
      add_error_handler status_code, &block
    end

    # All the helper methods available are:
    #  - before_all, before_get, before_post, before_put, before_patch, before_delete, before_options
    #  - after_all, after_get, after_post, after_put, after_patch, after_delete, after_options
    {% for type in ["before", "after"] %}
      {% for method in FILTER_METHODS %}
        # Add a filter for this class that runs {{type.id}} each `{{method.id.upcase}}` request (optionally limited to a specific *path*).
        #
        # The block receives an `HTTP::Server::Context` as argument.
        def {{type.id}}_{{method.id}}(path = "*", &block : HTTP::Server::Context -> _)
          filter_handler.{{type.id}}({{method}}.upcase, path, &block)
        end
      {% end %}
    {% end %}

    private macro initialize_defaults
      {% if CUSTOM_METHODS_REGISTRY[@type] %}
      {% for handler in CUSTOM_METHODS_REGISTRY[@type][:handlers] %}
      self.{{handler[0].id}}({{handler[1]}}) do |context|
        {{handler[2].id}}(context)
      end
      {% end %}

      {% for ws in CUSTOM_METHODS_REGISTRY[@type][:ws] %}
      self.ws({{handler[0]}}) do |websocket, context|
        {{handler[1].id}}(websocket, context)
      end
      {% end %}

      {% for ws in CUSTOM_METHODS_REGISTRY[@type][:error] %}
      self.add_error_handler({{handler[0]}}) do |context|
        {{handler[1].id}}(context)
      end
      {% end %}

      {% for filter in CUSTOM_METHODS_REGISTRY[@type][:filters] %}
        filter_handler.{{filter[0]}}({{filter[1]}}, {{filter[2]}}) do |context|
          {{filter[3]}}(context)
        end
      {% end %}
      {% end %}
    end
  end

  module MacroDSL
    {% for method in DSL::HTTP_METHODS %}
      # Define a `{{method.id.upcase}}` handler for this class.
      #
      # It will be initialized in every instance.
      # The block receives an `HTTP::Server::Context` as argument and is scoped to the instance.
      #
      # Example:
      # ```
      # class MyClass < Kemal::Base
      #   {{method.id}}("/route") do |context|
      #     # ...
      #   end
      # end
      # ```
      # NOTE: This macro *must* be called from class scope as it expands to a custom method definition.
      macro {{method.id}}(path, &block)
        \{% raise "invalid path start for {{method.id}}: path must start with \"/\"" unless path.starts_with?("/") %}
        \{% method_name = "__{{method.id}}_#{path.id.gsub(/[^a-zA-Z0-9]/,"_").gsub(/__+/, "_").gsub(/\A_|_\z/, "")}_#{CUSTOM_METHODS_REGISTRY[@type][:handlers].size}" %}
        def \{{method_name.id}}(\{{block.args[0].id}})
          \{{block.body}}
        end
        \{% CUSTOM_METHODS_REGISTRY[@type][:handlers] << { {{method}}, path, method_name } %}
      end
    {% end %}

    # Define a webservice handler for this class.
    #
    # It will be initialized in every instance.
    # The block receives `HTTP::WebSocket` and `HTTP::Server::Context` as arguments and is scoped to the instance.
    #
    # Example:
    # ```
    # class MyClass < Kemal::Base
    #   ws("/wsroute") do |context|
    #     # ...
    #   end
    # end
    # ```
    # NOTE: This macro *must* be called from class scope as it expands to a custom method definition.
    macro ws(path, &block)
        \{% raise "invalid path start for webservice: path must start with \"/\"" unless path.starts_with?("/") %}
      \{% method_name = "__ws_#{path.id.gsub(/[^a-zA-Z0-9]/,"_").gsub(/__+/, "_").gsub(/\A_|_\z/, "")}_#{CUSTOM_METHODS_REGISTRY[@type][:ws].size}" %}
      def \{{method_name.id}}(\{{block.args[0].id}}, \{{block.args[1].id}})
        \{{block.body}}
      end
      \{% CUSTOM_METHODS_REGISTRY[@type][:ws] << { path, method_name } %}
    end

    # Define an error handler for this class.
    #
    # It will be initialized in every instance.
    # The block receives `HTTP::Server::Context` and `Exception` as arguments and is scoped to the instance.
    #
    # Example:
    # ```
    # class MyClass < Kemal::Base
    #   error(403) do |context|
    #     # ...
    #   end
    # end
    # ```
    # NOTE: This macro *must* be called from class scope as it expands to a custom method definition.
    macro error(status_code)
      \{% method_name = "__error_#{status_code}_#{CUSTOM_METHODS_REGISTRY[@type][:error].size}" %}
      def \{{method_name.id}}(\{{block.args[0].id}})
        \{{block.body}}
      end
      \{% CUSTOM_METHODS_REGISTRY[@type][:error] << { status_code, method_name } %}
    end

    {% for type in ["before", "after"] %}
      {% for method in DSL::FILTER_METHODS %}
        # Define a filter for this class that runs {{type.id}} each `{{method.id.upcase}}` request (optionally limited to a specific *path*).
        #
        # The filter will be initialized in every instance of this class.
        # The block receives an `HTTP::Context` as argument and is scoped to the instance.
        #
        # Example:
        # ```
        # class MyClass < Kemal::Base
        #   {{type.id}}_{{method.id}}("/route") do |context|
        #     # ...
        #   end
        # end
        # ```
        # NOTE: This macro *must* be called from class scope as it expands to a custom method definition.
        macro {{type.id}}_{{method.id}}(path = "*", &block)
          \{% method_name = "__{{type.id}}_{{method.id}}_#{path.id.gsub(/[^a-zA-Z0-9]/,"_").gsub(/__+/, "_").gsub(/\A_|_\z/, "")}_#{CUSTOM_METHODS_REGISTRY[@type][:handlers].size}" %}
          def \{{method_name.id}}(\{{block.args[0].id}})
            \{{block.body}}
          end
          \{% CUSTOM_METHODS_REGISTRY[@type][:fitlers] << { {{type}}, {{method}}, path, method_name } %}
        end
      {% end %}
    {% end %}
  end
end
