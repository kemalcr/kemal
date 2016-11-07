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
    if @@only_routes_tree || @@exclude_routes_tree
      only_found = false
      exclude_found = false
      if @@only_routes_tree
        only_found = @@only_routes_tree.find(radix_path(env.request.method, env.request.path)).found?
      end

      if @@exclude_routes_tree
        exclude_found = @@exclude_routes_tree.find(radix_path(env.request.method, env.request.path)).found?
      end

      if !exclude_found || only_found
        return false
      else
        return true
      end
    end
    return false
  end

  private def radix_path(method : String, path)
    "#{self.class}/#{method.downcase}#{path}"
  end
end
