require "../src/kemal"

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

my_app = MyApp.new
my_app.config.app_name = "MyApp"

spawn { my_app.run(3002) }

OtherApp.run(3001)
