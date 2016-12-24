class Kemal::Handler
  include HTTP::Handler
  @@only_routes_tree = Radix::Tree(String).new
  @@exclude_routes_tree = Radix::Tree(String).new

  macro only(paths, method = "GET")
    class_name = {{@type.name}}
    {{paths}}.each do |path|
      @@only_routes_tree.add "#{class_name}/#{{{method}}.downcase}#{path}", "/#{{{method}}.downcase}#{path}"
    end
  end

  macro exclude(paths, method = "GET")
    class_name = {{@type.name}}
    {{paths}}.each do |path|
      @@exclude_routes_tree.add "#{class_name}/#{{{method}}.downcase}#{path}", "/#{{{method}}.downcase}#{path}"
    end
  end

  def call(env)
    call_next(env)
  end

  # Processes the path based on `only` paths which is a `Array(String)`.
  # If the path is not found on `only` conditions the handler will continue processing.
  # If the path is found in `only` conditions it'll stop processing and will pass the request
  # to next handler.
  #
  # However this is not done automatically. All handlers must inherit from `Kemal::Handler`.
  #
  #     class OnlyHandler < Kemal::Handler
  #       only ["/"]
  #
  #       def call(env)
  #         return call_next(env) unless only_match?(env)
  #         puts "If the path is / i will be doing some processing here."
  #       end
  #     end
  def only_match?(env)
    @@only_routes_tree.find(radix_path(env.request.method, env.request.path)).found?
  end

  # Processes the path based on `exclude` paths which is a `Array(String)`.
  # If the path is not found on `exclude` conditions the handler will continue processing.
  # If the path is found in `exclude` conditions it'll stop processing and will pass the request
  # to next handler.
  #
  # However this is not done automatically. All handlers must inherit from `Kemal::Handler`.
  #
  #     class ExcludeHandler < Kemal::Handler
  #       exclude ["/"]
  #
  #       def call(env)
  #         return call_next(env) if exclude_match?(env)
  #         puts "If the path is not / i will be doing some processing here."
  #       end
  #     end
  def exclude_match?(env)
    @@exclude_routes_tree.find(radix_path(env.request.method, env.request.path)).found?
  end

  private def radix_path(method : String, path)
    "#{self.class}/#{method.downcase}#{path}"
  end
end
