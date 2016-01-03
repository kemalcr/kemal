require "spec"
require "../src/kemal/*"
require "../src/kemal/middleware/*"

include Kemal

Spec.before_each do
  Kemal.config.env = "development"
  Kemal.config.handlers.clear
end
