require "../src/kemal/base"

class MyApp < Kemal::Application
  get "/" do |env|
    "Hello Kemal!"
  end
end

class OtherApp < Kemal::Application
  get "/" do |env|
    "Hello World!"
  end
end

spawn { MyApp.run(3002) }

OtherApp.run(3001)
