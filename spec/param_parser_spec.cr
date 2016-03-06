require "./spec_helper"

describe "ParamParser" do
  it "parses query params" do
    route = Route.new "POST", "/" do |env|
      hasan = env.params.query["hasan"]
      "Hello #{hasan}"
    end
    request = HTTP::Request.new("POST", "/?hasan=cemal")
    query_params = Kemal::ParamParser.new(request).params.query
    query_params["hasan"].should eq "cemal"
  end

  it "parses url params" do
    kemal = Kemal::RouteHandler::INSTANCE
    kemal.add_route "POST", "/hello/:hasan" do |env|
      "hello #{env.params.url["hasan"]}"
    end
    request = HTTP::Request.new("POST", "/hello/cemal")
    # Radix tree MUST be run to parse url params.
    io_with_context = create_request_and_return_io(kemal, request)
    url_params = Kemal::ParamParser.new(request).params.url
    url_params["hasan"].should eq "cemal"
  end

  it "parses request body" do
    route = Route.new "POST", "/" do |env|
      name = env.params.query["name"]
      age = env.params.query["age"]
      hasan = env.params.body["hasan"]
      "Hello #{name} #{hasan} #{age}"
    end

    request = HTTP::Request.new(
      "POST",
      "/?hasan=cemal",
      body: "name=serdar&age=99",
      headers: HTTP::Headers{"Content-Type": "application/x-www-form-urlencoded"},
    )

    query_params = Kemal::ParamParser.new(request).params.query
    query_params.should eq({"hasan" => "cemal"})

    body_params = Kemal::ParamParser.new(request).params.body
    body_params.should eq({"name" => "serdar", "age" => "99"})
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

      json_params = Kemal::ParamParser.new(request).params.json
      json_params.should eq({"name": "Serdar"})
    end

    it "parses request body for array" do
      route = Route.new "POST", "/" { }

      request = HTTP::Request.new(
        "POST",
        "/",
        body: "[1]",
        headers: HTTP::Headers{"Content-Type": "application/json"},
      )

      json_params = Kemal::ParamParser.new(request).params.json
      json_params.should eq({"_json": [1]})
    end

    it "parses request body and query params" do
      route = Route.new "POST", "/" { }

      request = HTTP::Request.new(
        "POST",
        "/?foo=bar",
        body: "[1]",
        headers: HTTP::Headers{"Content-Type": "application/json"},
      )

      query_params = Kemal::ParamParser.new(request).params.query
      query_params.should eq({"foo": "bar"})

      json_params = Kemal::ParamParser.new(request).params.json
      json_params.should eq({"_json": [1]})
    end

    it "handles no request body" do
      route = Route.new "GET", "/" { }

      request = HTTP::Request.new(
        "GET",
        "/",
        headers: HTTP::Headers{"Content-Type": "application/json"},
      )

      url_params = Kemal::ParamParser.new(request).params.url
      url_params.should eq({} of String => String)

      query_params = Kemal::ParamParser.new(request).params.query
      query_params.should eq({} of String => String)

      body_params = Kemal::ParamParser.new(request).params.body
      body_params.should eq({} of String => String)

      json_params = Kemal::ParamParser.new(request).params.json
      json_params.should eq({} of String => AllParamTypes)
    end
  end

  context "when content type is incorrect" do
    it "does not parse request body" do
      route = Route.new "POST", "/" do |env|
        name = env.params.body["name"]
        age = env.params.body["age"]
        hasan = env.params.query["hasan"]
        "Hello #{name} #{hasan} #{age}"
      end

      request = HTTP::Request.new(
        "POST",
        "/?hasan=cemal",
        body: "name=serdar&age=99",
        headers: HTTP::Headers{"Content-Type": "text/plain"},
      )

      query_params = Kemal::ParamParser.new(request).params.query
      query_params.should eq({"hasan" => "cemal"})

      body_params = Kemal::ParamParser.new(request).params.body
      body_params.should eq({} of String => String)
    end
  end
end
