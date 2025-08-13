require "kemal"

logging false

get "/" do
  "Hello World"
end

Kemal.run
