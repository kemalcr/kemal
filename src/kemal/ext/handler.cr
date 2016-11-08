class Kemal::Handler < HTTP::Handler
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
  #     OnlyHandler < Kemal::Handler
  #       only ["/"]
  #
  #       def call(env)
  #         return unless only_match?(env)
  #         puts "If the path is / i will be doing some processing here."
  #       end
  #     end
  def only_match?(env)
    if @@only_routes_tree
      only_found = false
      only_found? = @@only_routes_tree.find(radix_path(env.request.method, env.request.path)).found?
      return only_found?
    end
    false
  end

  # Processes the path based on `exclude` paths which is a `Array(String)`.
  # If the path is not found on `exclude` conditions the handler will continue processing.
  # If the path is found in `exclude` conditions it'll stop processing and will pass the request
  # to next handler.
  #
  # However this is not done automatically. All handlers must inherit from `Kemal::Handler`.
  #
  #     ExcludeHandler < Kemal::Handler
  #       exclude ["/"]
  #
  #       def call(env)
  #         return unless exclude_match?(env)
  #         puts "If the path is / i will be doing some processing here."
  #       end
  #     end
  def exclude_match?(env)
    if @@exclude_routes_tree
      exclude_found = false
      exclude_found? = @@exclude_routes_tree.find(radix_path(env.request.method, env.request.path)).found?
      return !exclude_found?
    end
    false
  end

  private def radix_path(method : String, path)
    "#{self.class}/#{method.downcase}#{path}"
  end
end
