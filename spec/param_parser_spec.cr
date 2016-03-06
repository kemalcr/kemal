require "./spec_helper"

describe "ParamParser" do
  it "parses query params" do
    route = Route.new "POST", "/" do |env|
      hasan = env.params["hasan"]
      "Hello #{hasan}"
    end
    request = HTTP::Request.new("POST", "/?hasan=cemal")
    params = Kemal::ParamParser.new(request).parse
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

    params = Kemal::ParamParser.new(request).parse
    params.should eq({"hasan" => "cemal", "name" => "serdar", "age" => "99"})
  end

  context "when content type is application/json" do
    it "parses request body" do
      route = Route.new "POST", "/" { }

      request = HTTP::Request.new(
        "POST",
        "/",
        body: "{\"name\": \"Serdar\"}",
        headers: HTTP::Headers{"Content-Type": "application/json"},
      )

      params = Kemal::ParamParser.new(request).parse
      params.should eq({"name": "Serdar"})
    end

    it "parses request body for array" do
      route = Route.new "POST", "/" { }

      request = HTTP::Request.new(
        "POST",
        "/",
        body: "[1]",
        headers: HTTP::Headers{"Content-Type": "application/json"},
      )

      params = Kemal::ParamParser.new(request).parse
      params.should eq({"_json": [1]})
    end

    it "parses request body and query params" do
      route = Route.new "POST", "/" { }

      request = HTTP::Request.new(
        "POST",
        "/?foo=bar",
        body: "[1]",
        headers: HTTP::Headers{"Content-Type": "application/json"},
      )

      params = Kemal::ParamParser.new(request).parse
      params.should eq({"foo": "bar", "_json": [1]})
    end

    it "handles no request body" do
      route = Route.new "GET", "/" { }

      request = HTTP::Request.new(
        "GET",
        "/",
        headers: HTTP::Headers{"Content-Type": "application/json"},
      )

      params = Kemal::ParamParser.new(request).parse
      params.should eq({} of String => AllParamTypes)
    end
  end

  context "when content type is application/msgpack" do
    it "parses requests body" do
      packer = MessagePack::Packer.new
      packer.write({"foo": "bar"})
      io = MemoryIO.new
      io.set_encoding "UTF-8"
      io.write(packer.to_slice)
      request = HTTP::Request.new(
        "POST",
        "/",
        body: io.to_s,
        headers: HTTP::Headers{"Content-Type": "application/msgpack"},
      )
      params = Kemal::ParamParser.new(request).parse
      params.should eq({"foo" => "bar"})
    end
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

      params = Kemal::ParamParser.new(request).parse
      params.should eq({"hasan" => "cemal"})
    end
  end
end
