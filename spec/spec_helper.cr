require "spec"
require "../src/kemal/*"

include Kemal

Spec.before_each do
  Kemal.config.env = "development"
end
