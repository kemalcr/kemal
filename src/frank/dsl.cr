def get(path, &block : Frank::Request -> String)
  Frank::Handler::INSTANCE.add_route("GET", path, &block)
end

def post(path, &block : Frank::Request -> String)
  Frank::Handler::INSTANCE.add_route("POST", path, &block)
end
