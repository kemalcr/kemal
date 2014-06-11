def get(path, &block : Frank::Request -> String)
  $frank_handler.add_route(path, block)
end
