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
end
