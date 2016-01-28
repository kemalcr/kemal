# Kemal::Filter handle all code that should be evaluated before and after
# every request

class Kemal::Filter
  property block, type

  def initialize(@type, @path, @options, &@block : -> _)
  end
end
