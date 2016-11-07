module Kemal
  # Route is the main building block of Kemal.
  # It takes 3 parameters: Method, path and a block to specify
  # what action to be done if the route is matched.
  class Route
    getter handler
    @handler : HTTP::Server::Context -> String
    @method : String

    def initialize(@method, @path : String, &handler : HTTP::Server::Context -> _)
      @handler = ->(context : HTTP::Server::Context) do
        handler.call(context).to_s
      end
    end
  end
end
