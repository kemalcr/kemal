require "spec"
require "../src/kemal/*"
require "../src/kemal/middleware/*"

include Kemal

class CustomTestHandler < HTTP::Handler
  def call(request)
    call_next request
  end
end

Spec.before_each do
  Kemal.config.env = "development"
  Kemal.config.handlers.clear
end
