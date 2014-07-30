def get(path, &block : Frank::Request -> String)
  Frank::Handler::INSTANCE.add_route(path, block)
end
