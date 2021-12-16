module Kemal
  class Application
    private CUSTOM_METHODS_REGISTRY = {} of _ => _

    macro inherited
      {% CUSTOM_METHODS_REGISTRY[@type] = {
           handlers: [] of _,
           ws:       [] of _,
           error:    [] of _,
           filters:  [] of _,
         } %}
    end

    def initialize
      initialize_routes
    end

    macro initialize_routes
      {% if CUSTOM_METHODS_REGISTRY[@type] %}
        {% for handler in CUSTOM_METHODS_REGISTRY[@type][:handlers] %}
        self.{{handler[0].id}}({{handler[1]}}) {{handler[2]}}
        {% end %}

        {% for ws in CUSTOM_METHODS_REGISTRY[@type][:ws] %}
        self.ws({{handler[0]}}) {{handler[1]}}
        {% end %}

        {% for error in CUSTOM_METHODS_REGISTRY[@type][:error] %}
        self.add_error_handler({{handler[0]}}) {{handler[1]}}
        {% end %}

        {% for filter in CUSTOM_METHODS_REGISTRY[@type][:filters] %}
        self.{{handler[0].id}}(handler[1]) {{handler[2]}}
        {% end %}
      {% end %}
    end
  end

  module Helpers
    module MacroDSL
      {% for method in DSL::HTTP_METHODS %}
        macro {{method.id}}(path, &block)
          \{% CUSTOM_METHODS_REGISTRY[@type][:handlers] << { {{method}}, path, block } %}
        end
      {% end %}

      macro ws(path, &block)
        {% pp "calling this with #{path}" %}
        {% CUSTOM_METHODS_REGISTRY[@type][:ws] << {path, block} %}
      end

      macro error(status_code, &block)
        {% CUSTOM_METHODS_REGISTRY[@type][:ws] << {status_code, block} %}
      end

      {% for type in ["before", "after"] %}
        {% for method in DSL::FILTER_METHODS %}
          macro {{type.id}}_{{method.id}}(path_or_paths = "*", &block)
            \{% CUSTOM_METHODS_REGISTRY[@type][:filters] << { {{type.id}}_{{method.id}}, path_or_paths, block } %}
          end
        {% end %}
      {% end %}
    end
  end
end
