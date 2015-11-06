require "./spec_helper"

describe "ParamParser" do
  it "parses query params" do
    route = Route.new "POST", "/" do |env|
      hasan = env.params["hasan"]
      "Hello #{hasan}"
    end
    request = HTTP::Request.new("POST", "/?hasan=cemal")
    params = Kemal::ParamParser.new(route, request).parse
    params["hasan"].should eq "cemal"
  end

  it "parses request body" do
    route = Route.new "POST", "/" do |env|
      name = env.params["name"]
      age = env.params["age"]
      hasan = env.params["hasan"]
      "Hello #{name} #{hasan} #{age}"
    end

    request = HTTP::Request.new(
      "POST",
      "/?hasan=cemal",
      body: "name=serdar&age=99",
      headers: HTTP::Headers{"Content-Type": "application/x-www-form-urlencoded"},
    )

    params = Kemal::ParamParser.new(route, request).parse
    params.should eq({"hasan" => "cemal", "name" => "serdar", "age" => "99"})
  end

  it "parses request body" do
    route = Route.new "POST", "/" { }

    request = HTTP::Request.new(
      "POST",
      "/",
      body: "{\"name\": \"Serdar\"}",
      headers: HTTP::Headers{"Content-Type": "application/json"},
    )

    params = Kemal::ParamParser.new(route, request).parse
    params.should eq({"name": "Serdar"})
  end

  context "when content type is incorrect" do
    it "does not parse request body" do
      route = Route.new "POST", "/" do |env|
        name = env.params["name"]
        age = env.params["age"]
        hasan = env.params["hasan"]
        "Hello #{name} #{hasan} #{age}"
      end

      request = HTTP::Request.new(
        "POST",
        "/?hasan=cemal",
        body: "name=serdar&age=99",
        headers: HTTP::Headers{"Content-Type": "text/plain"},
      )

      params = Kemal::ParamParser.new(route, request).parse
      params.should eq({"hasan" => "cemal"})
    end
  end
end
