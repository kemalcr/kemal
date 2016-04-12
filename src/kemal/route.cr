# Route is the main building block of Kemal.
# It takes 3 parameters: Method, path and a block to specify
# what action to be done if the route is matched.
class Kemal::Route
  getter handler : (HTTP::Server::Context -> )
  getter method

  def initialize(@method : String, @path : String, &@handler : HTTP::Server::Context -> )
  end
end
