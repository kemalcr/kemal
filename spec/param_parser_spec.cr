require "./spec_helper"

describe "ParamParser" do
  it "parses params" do
    kemal = Kemal::Handler.new
    kemal.add_route "POST", "/" do |env|
      name = env.params["name"]
      age = env.params["age"]
      hasan = env.params["hasan"]
      "Hello #{name} #{hasan} #{age}"
    end
    request = HTTP::Request.new("POST", "/?hasan=cemal", body: "name=kemal&age=99")
    response = kemal.call(request)
    response.body.should eq("Hello kemal cemal 99")
  end
end
