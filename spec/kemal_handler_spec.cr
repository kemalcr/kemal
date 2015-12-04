require "./spec_helper"

describe "Kemal::Handler" do
  it "routes" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do
      "hello"
    end
    request = HTTP::Request.new("GET", "/")
    response = kemal.call(request)
    response.body.should eq("hello")
  end

  it "routes request with query string" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      "hello #{env.params["message"]}"
    end
    request = HTTP::Request.new("GET", "/?message=world")
    response = kemal.call(request)
    response.body.should eq("hello world")
  end

  it "routes request with multiple query strings" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      "hello #{env.params["message"]} time #{env.params["time"]}"
    end
    request = HTTP::Request.new("GET", "/?message=world&time=now")
    response = kemal.call(request)
    response.body.should eq("hello world time now")
  end

  it "route parameter has more precedence than query string arguments" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/:message" do |env|
      "hello #{env.params["message"]}"
    end
    request = HTTP::Request.new("GET", "/world?message=coco")
    response = kemal.call(request)
    response.body.should eq("hello world")
  end

  it "parses simple JSON body" do
    kemal = Kemal::Handler.new
    kemal.add_route "POST", "/" do |env|
      name = env.params["name"]
      age = env.params["age"]
      "Hello #{name} Age #{age}"
    end

    json_payload = {"name": "Serdar", "age": 26}
    request = HTTP::Request.new(
      "POST",
      "/",
      body: json_payload.to_json,
      headers: HTTP::Headers{"Content-Type": "application/json"},
    )

    response = kemal.call(request)
    response.body.should eq("Hello Serdar Age 26")
  end

  it "parses JSON with string array" do
    kemal = Kemal::Handler.new
    kemal.add_route "POST", "/" do |env|
      skills = env.params["skills"] as Array
      "Skills #{skills.each.join(',')}"
    end

    json_payload = {"skills": ["ruby", "crystal"]}
    request = HTTP::Request.new(
      "POST",
      "/",
      body: json_payload.to_json,
      headers: HTTP::Headers{"Content-Type": "application/json"},
    )

    response = kemal.call(request)
    response.body.should eq("Skills ruby,crystal")
  end

  it "parses JSON with json object array" do
    kemal = Kemal::Handler.new
    kemal.add_route "POST", "/" do |env|
      skills = env.params["skills"] as Array
      skills_from_languages = skills.map do |skill|
        skill = skill as Hash
        skill["language"]
      end
      "Skills #{skills_from_languages.each.join(',')}"
    end

    json_payload = {"skills": [{"language": "ruby"}, {"language": "crystal"}]}
    request = HTTP::Request.new(
      "POST",
      "/",
      body: json_payload.to_json,
      headers: HTTP::Headers{"Content-Type": "application/json"},
    )

    response = kemal.call(request)
    response.body.should eq("Skills ruby,crystal")
  end

  it "renders 404 on not found" do
    kemal = Kemal::Handler.new
    request = HTTP::Request.new("GET", "/?message=world")
    response = kemal.call(request)
    response.status_code.should eq 404
  end

  it "renders 500 on exception" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do
      raise "Exception"
    end
    request = HTTP::Request.new("GET", "/?message=world")
    response = kemal.call(request)
    response.status_code.should eq 500
    response.body.includes?("Exception").should eq true
  end

  it "checks for _method param in POST request to simulate PUT" do
    kemal = Kemal::Handler.new
    kemal.add_route "PUT", "/", do |env|
      "Hello World from PUT"
    end
    request = HTTP::Request.new(
      "POST",
      "/",
      body: "_method=PUT",
      headers: HTTP::Headers{"Content-Type": "application/x-www-form-urlencoded"}
    )
    response = kemal.call(request)
    response.body.should eq("Hello World from PUT")
  end

  it "checks for _method param in POST request to simulate PATCH" do
    kemal = Kemal::Handler.new
    kemal.add_route "PATCH", "/", do |env|
      "Hello World from PATCH"
    end
    request = HTTP::Request.new(
      "POST",
      "/",
      body: "_method=PATCH",
      headers: HTTP::Headers{"Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"}
    )
    response = kemal.call(request)
    response.body.should eq("Hello World from PATCH")
  end

  it "checks for _method param in POST request to simulate DELETE" do
    kemal = Kemal::Handler.new
    kemal.add_route "DELETE", "/", do |env|
      "Hello World from DELETE"
    end
    json_payload = {"_method": "DELETE"}
    request = HTTP::Request.new(
      "POST",
      "/",
      body: json_payload.to_json,
      headers: HTTP::Headers{"Content-Type": "application/json"}
    )
    response = kemal.call(request)
    response.body.should eq("Hello World from DELETE")
  end

  it "can process HTTP HEAD requests for defined GET routes" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      "Hello World from GET"
    end
    request = HTTP::Request.new("HEAD", "/")
    response = kemal.call(request)
    response.status_code.should eq(200)
  end

  it "can't process HTTP HEAD requests for undefined GET routes" do
    kemal = Kemal::Handler.new
    request = HTTP::Request.new("HEAD", "/")
    response = kemal.call(request)
    response.status_code.should eq(404)
  end

  it "redirects user to provided url" do
    kemal = Kemal::Handler.new
    kemal.add_route "GET", "/" do |env|
      env.redirect("/login")
    end
    request = HTTP::Request.new("GET", "/")
    response = kemal.call(request)
    response.status_code.should eq(301)
    response.headers.has_key?("Location").should eq(true)
  end

end
