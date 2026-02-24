require "./spec_helper"

describe "ParamParser" do
  it "parses query params" do
    Route.new "POST", "/" do |env|
      hasan = env.params.query["hasan"]
      "Hello #{hasan}"
    end
    request = HTTP::Request.new("POST", "/?hasan=cemal")
    query_params = Kemal::ParamParser.new(request).query
    query_params["hasan"].should eq "cemal"
  end

  it "parses multiple values for query params" do
    Route.new "POST", "/" do |env|
      hasan = env.params.query["hasan"]
      "Hello #{hasan}"
    end
    request = HTTP::Request.new("POST", "/?hasan=cemal&hasan=lamec")
    query_params = Kemal::ParamParser.new(request).query
    query_params.fetch_all("hasan").should eq ["cemal", "lamec"]
  end

  it "parses url params" do
    kemal = Kemal::RouteHandler::INSTANCE
    kemal.add_route "POST", "/hello/:hasan" do |env|
      "hello #{env.params.url["hasan"]}"
    end
    request = HTTP::Request.new("POST", "/hello/cemal")
    # Radix tree MUST be run to parse url params.
    context = create_request_and_return_io_and_context(kemal, request)[1]
    url_params = Kemal::ParamParser.new(request, context.route_lookup.params).url
    url_params["hasan"].should eq "cemal"
  end

  it "decodes url params" do
    kemal = Kemal::RouteHandler::INSTANCE
    kemal.add_route "POST", "/hello/:email/:money/:spanish" do |env|
      email = env.params.url["email"]
      money = env.params.url["money"]
      spanish = env.params.url["spanish"]
      "Hello, #{email}. You have #{money}. The spanish word of the day is #{spanish}."
    end
    request = HTTP::Request.new("POST", "/hello/sam%2Bspec%40gmail.com/%2419.99/a%C3%B1o")
    # Radix tree MUST be run to parse url params.
    context = create_request_and_return_io_and_context(kemal, request)[1]
    url_params = Kemal::ParamParser.new(request, context.route_lookup.params).url
    url_params["email"].should eq "sam+spec@gmail.com"
    url_params["money"].should eq "$19.99"
    url_params["spanish"].should eq "año"
  end

  it "parses request body" do
    Route.new "POST", "/" do |env|
      name = env.params.query["name"]
      age = env.params.query["age"]
      hasan = env.params.body["hasan"]
      "Hello #{name} #{hasan} #{age}"
    end

    request = HTTP::Request.new(
      "POST",
      "/?hasan=cemal",
      body: "name=serdar&age=99",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
    )

    query_params = Kemal::ParamParser.new(request).query
    {"hasan" => "cemal"}.each do |k, v|
      query_params[k].should eq(v)
    end

    body_params = Kemal::ParamParser.new(request).body
    {"name" => "serdar", "age" => "99"}.each do |k, v|
      body_params[k].should eq(v)
    end
  end

  it "parses multiple values in request body" do
    Route.new "POST", "/" do |env|
      hasan = env.params.body["hasan"]
      "Hello #{hasan}"
    end

    request = HTTP::Request.new(
      "POST",
      "/",
      body: "hasan=cemal&hasan=lamec",
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
    )

    body_params = Kemal::ParamParser.new(request).body
    body_params.fetch_all("hasan").should eq(["cemal", "lamec"])
  end

  context "when content type is application/json" do
    it "parses request body" do
      Route.new "POST", "/" { }

      request = HTTP::Request.new(
        "POST",
        "/",
        body: "{\"name\": \"Serdar\"}",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      json_params = Kemal::ParamParser.new(request).json
      json_params.should eq({"name" => "Serdar"})
    end

    it "parses request body when passed charset" do
      Route.new "POST", "/" { }

      request = HTTP::Request.new(
        "POST",
        "/",
        body: "{\"name\": \"Serdar\"}",
        headers: HTTP::Headers{"Content-Type" => "application/json; charset=utf-8"},
      )

      json_params = Kemal::ParamParser.new(request).json
      json_params.should eq({"name" => "Serdar"})
    end

    it "parses request body for array" do
      Route.new "POST", "/" { }

      request = HTTP::Request.new(
        "POST",
        "/",
        body: "[1]",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      json_params = Kemal::ParamParser.new(request).json
      json_params.should eq({"_json" => [1]})
    end

    it "parses request body and query params" do
      Route.new "POST", "/" { }

      request = HTTP::Request.new(
        "POST",
        "/?foo=bar",
        body: "[1]",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      query_params = Kemal::ParamParser.new(request).query
      {"foo" => "bar"}.each do |k, v|
        query_params[k].should eq(v)
      end

      json_params = Kemal::ParamParser.new(request).json
      json_params.should eq({"_json" => [1]})
    end

    it "handles no request body" do
      Route.new "GET", "/" { }

      request = HTTP::Request.new(
        "GET",
        "/",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      url_params = Kemal::ParamParser.new(request).url
      url_params.should eq({} of String => String)

      query_params = Kemal::ParamParser.new(request).query
      query_params.to_s.should eq("")

      body_params = Kemal::ParamParser.new(request).body
      body_params.to_s.should eq("")

      json_params = Kemal::ParamParser.new(request).json
      json_params.should eq({} of String => String | Int64 | Float64 | Bool | Hash(String, JSON::Any) | Array(JSON::Any)?)
    end
  end

  context "when content type is incorrect" do
    it "does not parse request body" do
      Route.new "POST", "/" do |env|
        name = env.params.body["name"]
        age = env.params.body["age"]
        hasan = env.params.query["hasan"]
        "Hello #{name} #{hasan} #{age}"
      end

      request = HTTP::Request.new(
        "POST",
        "/?hasan=cemal",
        body: "name=serdar&age=99",
        headers: HTTP::Headers{"Content-Type" => "text/plain"},
      )

      query_params = Kemal::ParamParser.new(request).query
      query_params["hasan"].should eq("cemal")

      body_params = Kemal::ParamParser.new(request).body
      body_params.to_s.should eq("")
    end
  end

  describe "raw_body" do
    it "returns raw body for url-encoded form" do
      request = HTTP::Request.new(
        "POST",
        "/",
        body: "name=serdar&age=99",
        headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
      )

      parser = Kemal::ParamParser.new(request)
      parser.raw_body.should eq("name=serdar&age=99")
      parser.body["name"].should eq("serdar")
      parser.body["age"].should eq("99")
    end

    it "returns raw body for JSON" do
      request = HTTP::Request.new(
        "POST",
        "/",
        body: "{\"name\": \"Serdar\"}",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      parser = Kemal::ParamParser.new(request)
      parser.raw_body.should eq("{\"name\": \"Serdar\"}")
      parser.json["name"].should eq("Serdar")
    end

    it "caches body so it can be accessed multiple times" do
      request = HTTP::Request.new(
        "POST",
        "/",
        body: "foo=bar&baz=qux",
        headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
      )

      parser = Kemal::ParamParser.new(request)
      parser.raw_body.should eq("foo=bar&baz=qux")
      parser.raw_body.should eq("foo=bar&baz=qux")
      parser.body["foo"].should eq("bar")
      parser.raw_body.should eq("foo=bar&baz=qux")
    end

    it "returns empty string for unsupported content types" do
      request = HTTP::Request.new(
        "POST",
        "/",
        body: "some body",
        headers: HTTP::Headers{"Content-Type" => "text/plain"},
      )

      parser = Kemal::ParamParser.new(request)
      parser.raw_body.should eq("")
    end

    it "returns empty string when content-type is missing" do
      request = HTTP::Request.new("POST", "/", body: "some body")

      parser = Kemal::ParamParser.new(request)
      parser.raw_body.should eq("")
    end
  end

  context "Payload too large" do
    it "raises PayloadTooLarge when body exceeds limit" do
      Kemal.config.max_request_body_size = 10
      request = HTTP::Request.new(
        "POST",
        "/",
        body: "12345678901",
        headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
      )

      expect_raises(Kemal::Exceptions::PayloadTooLarge) do
        Kemal::ParamParser.new(request).body
      end
    end

    it "raises PayloadTooLarge when Content-Length exceeds limit" do
      Kemal.config.max_request_body_size = 10
      request = HTTP::Request.new(
        "POST",
        "/",
        body: "1",
        headers: HTTP::Headers{
          "Content-Type" => "application/x-www-form-urlencoded",
        },
      )
      request.headers["Content-Length"] = "11"

      expect_raises(Kemal::Exceptions::PayloadTooLarge) do
        Kemal::ParamParser.new(request).body
      end
    end

    it "parses body when size is within limit" do
      Kemal.config.max_request_body_size = 20
      request = HTTP::Request.new(
        "POST",
        "/",
        body: "name=serdar",
        headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
      )

      body_params = Kemal::ParamParser.new(request).body
      body_params["name"].should eq("serdar")
    end

    it "raises PayloadTooLarge for JSON body exceeding limit" do
      Kemal.config.max_request_body_size = 10
      request = HTTP::Request.new(
        "POST",
        "/",
        body: "{\"foo\":\"bar\"}",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      expect_raises(Kemal::Exceptions::PayloadTooLarge) do
        Kemal::ParamParser.new(request).json
      end
    end
  end
end
