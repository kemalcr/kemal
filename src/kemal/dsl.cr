def get(path, &block : Kemal::Context -> _)
  Kemal::Handler::INSTANCE.add_route("GET", path, &block)
end

def post(path, &block : Kemal::Context -> _)
  Kemal::Handler::INSTANCE.add_route("POST", path, &block)
end
