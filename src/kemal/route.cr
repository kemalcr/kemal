# Route is the main building block of Kemal.
# It takes 3 parameters: Method, path and a block to specify
# what action to be done if the route is matched.
class Kemal::Route
  getter handler
  getter pattern

  def initialize(@method, path, &@handler : Kemal::Context -> _)
    @pattern = pattern_to_regex path
  end

  private def pattern_to_regex(pattern)
    pattern = pattern.gsub(/\:(?<param>\w+)/) do |_, match|
      "(?<#{match["param"]}>.*)"
    end
    Regex.new "^#{pattern}/?$"
  end

end
