require "./spec_helper"

describe "ParamParser" do
  it "parses query params" do
    request = HTTP::Request.new("POST", "/?hasan=cemal")
    param_parser = Kemal::ParamParser.new(request)
    param_parser.parse
    query_params = param_parser.params
    query_params["hasan"].should eq "cemal"
  end

  # it "parses multiple values for query params" do
  #   request = HTTP::Request.new("POST", "/?hasan=cemal&hasan=lamec")
  #   query_params = Kemal::ParamParser.new(request).params
  #   query_params.fetch_all("hasan").should eq ["cemal", "lamec"]
  # end

  it "parses url params" do
    kemal = Kemal::RouteHandler::INSTANCE
    kemal.add_route "POST", "/hello/:hasan" do |env|
      "hello #{env.params["hasan"]}"
    end
    request = HTTP::Request.new("POST", "/hello/cemal")
    # Radix tree MUST be run to parse url params.
    io_with_context = create_request_and_return_io(kemal, request)
    param_parser = Kemal::ParamParser.new(request)
    param_parser.parse
    url_params = param_parser.params
    url_params["hasan"].should eq "cemal"
  end

  it "decodes url params" do
    kemal = Kemal::RouteHandler::INSTANCE
    kemal.add_route "POST", "/hello/:email/:money/:spanish" do |env|
      email = env.params["email"]
      money = env.params["money"]
      spanish = env.params["spanish"]
      "Hello, #{email}. You have #{money}. The spanish word of the day is #{spanish}."
    end
    request = HTTP::Request.new("POST", "/hello/sam%2Bspec%40gmail.com/%2419.99/a%C3%B1o")
    # Radix tree MUST be run to parse url params.
    io_with_context = create_request_and_return_io(kemal, request)
    param_parser = Kemal::ParamParser.new(request)
    param_parser.parse
    url_params = param_parser.params
    url_params["email"].should eq "sam+spec@gmail.com"
    url_params["money"].should eq "$19.99"
    url_params["spanish"].should eq "año"
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
      headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
    )

    param_parser = Kemal::ParamParser.new(request)
    param_parser.parse
    params = param_parser.params
    {"hasan" => "cemal", "name" => "serdar", "age" => "99"}.each do |k, v|
      params[k].should eq(v)
    end
  end

  # it "parses multiple values in request body" do
  #   route = Route.new "POST", "/" do |env|
  #     hasan = env.params["hasan"]
  #     "Hello #{hasan}"
  #   end

  #   request = HTTP::Request.new(
  #     "POST",
  #     "/",
  #     body: "hasan=cemal&hasan=lamec",
  #     headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
  #   )

  #   param_parser = Kemal::ParamParser.new(request)
  #   param_parser.parse
  #   body_params = param_parser.params
  #   body_params.fetch_all("hasan").should eq(["cemal", "lamec"])
  # end

  context "when content type is application/json" do
    it "parses request body" do
      route = Route.new "POST", "/" { }

      request = HTTP::Request.new(
        "POST",
        "/",
        body: "{\"name\": \"Serdar\"}",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      param_parser = Kemal::ParamParser.new(request)
      param_parser.parse
      json_params = param_parser.params
      json_params.should eq({"name" => "Serdar"})
    end

    it "parses request body when passed charset" do
      route = Route.new "POST", "/" { }

      request = HTTP::Request.new(
        "POST",
        "/",
        body: "{\"name\": \"Serdar\"}",
        headers: HTTP::Headers{"Content-Type" => "application/json; charset=utf-8"},
      )

      param_parser = Kemal::ParamParser.new(request)
      param_parser.parse
      json_params = param_parser.params
      json_params.should eq({"name" => "Serdar"})
    end

    it "parses request body for array" do
      route = Route.new "POST", "/" { }

      request = HTTP::Request.new(
        "POST",
        "/",
        body: "[1]",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      param_parser = Kemal::ParamParser.new(request)
      param_parser.parse
      json_params = param_parser.params
      json_params.should eq({"_json" => [1]})
    end

    it "parses request body and query params" do
      route = Route.new "POST", "/" { }

      request = HTTP::Request.new(
        "POST",
        "/?foo=bar",
        body: "[1]",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      param_parser = Kemal::ParamParser.new(request)
      param_parser.parse
      json_params = param_parser.params

      {"foo" => "bar", "_json" => [1]}.each do |k, v|
        json_params[k].should eq(v)
      end
    end

    it "handles no request body" do
      route = Route.new "GET", "/" { }

      request = HTTP::Request.new(
        "GET",
        "/",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
      )

      param_parser = Kemal::ParamParser.new(request)
      param_parser.parse
      json_params = param_parser.params
      json_params.should eq({} of String => Nil | String | Int64 | Float64 | Bool | Hash(String, JSON::Type) | Array(JSON::Type))
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
        headers: HTTP::Headers{"Content-Type" => "text/plain"},
      )

      param_parser = Kemal::ParamParser.new(request)
      param_parser.parse
      query_params = param_parser.params
      query_params["hasan"].should eq("cemal")
      query_params["age"]?.should eq(nil)
      query_params["name"]?.should eq(nil)
    end
  end
end
