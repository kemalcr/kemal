# Route is the main building block of Kemal.
# It takes 3 parameters: Method, path and a block to specify
# what action to be done if the route is matched.
class Kemal::Route
  getter handler
  getter method

  def initialize(@method, @path, &@handler : HTTP::Server::Context -> _)
  end
end
