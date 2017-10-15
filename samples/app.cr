require "kemal/base"

class MyApp < Kemal::Application
  get "/" do
    "Hello Kemal!"
  end
end

MyApp.run
