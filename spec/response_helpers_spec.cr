require "./spec_helper"

describe "Response Helpers" do
  describe "#json" do
    it "sets content-type to application/json" do
      get "/json-test" do |env|
        env.json({message: "hello"})
      end

      request = HTTP::Request.new("GET", "/json-test")
      client_response = call_request_on_app(request)
      client_response.headers["Content-Type"].should eq("application/json")
    end

    it "serializes hash to JSON" do
      get "/json-hash" do |env|
        env.json({name: "alice", age: 30})
      end

      request = HTTP::Request.new("GET", "/json-hash")
      client_response = call_request_on_app(request)
      client_response.body.should eq(%({"name":"alice","age":30}))
    end

    it "serializes array to JSON" do
      get "/json-array" do |env|
        env.json([1, 2, 3])
      end

      request = HTTP::Request.new("GET", "/json-array")
      client_response = call_request_on_app(request)
      client_response.body.should eq("[1,2,3]")
    end

    it "accepts status_code parameter" do
      get "/json-status" do |env|
        env.json({created: true}, status_code: 201)
      end

      request = HTTP::Request.new("GET", "/json-status")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(201)
      client_response.headers["Content-Type"].should eq("application/json")
    end
  end

  describe "#html" do
    it "sets content-type to text/html" do
      get "/html-test" do |env|
        env.html("<h1>Hello</h1>")
      end

      request = HTTP::Request.new("GET", "/html-test")
      client_response = call_request_on_app(request)
      client_response.headers["Content-Type"].should eq("text/html; charset=utf-8")
    end

    it "returns HTML content" do
      get "/html-content" do |env|
        env.html("<div>Content</div>")
      end

      request = HTTP::Request.new("GET", "/html-content")
      client_response = call_request_on_app(request)
      client_response.body.should eq("<div>Content</div>")
    end

    it "accepts status_code parameter" do
      get "/html-status" do |env|
        env.html("<h1>Not Found</h1>", status_code: 404)
      end

      request = HTTP::Request.new("GET", "/html-status")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(404)
    end
  end

  describe "#text" do
    it "sets content-type to text/plain" do
      get "/text-test" do |env|
        env.text("Hello World")
      end

      request = HTTP::Request.new("GET", "/text-test")
      client_response = call_request_on_app(request)
      client_response.headers["Content-Type"].should eq("text/plain; charset=utf-8")
    end

    it "returns plain text content" do
      get "/text-content" do |env|
        env.text("Plain text here")
      end

      request = HTTP::Request.new("GET", "/text-content")
      client_response = call_request_on_app(request)
      client_response.body.should eq("Plain text here")
    end

    it "accepts status_code parameter" do
      get "/text-status" do |env|
        env.text("Service Unavailable", status_code: 503)
      end

      request = HTTP::Request.new("GET", "/text-status")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(503)
    end
  end

  describe "#xml" do
    it "sets content-type to application/xml" do
      get "/xml-test" do |env|
        env.xml("<root></root>")
      end

      request = HTTP::Request.new("GET", "/xml-test")
      client_response = call_request_on_app(request)
      client_response.headers["Content-Type"].should eq("application/xml; charset=utf-8")
    end

    it "returns XML content" do
      get "/xml-content" do |env|
        env.xml(%(<?xml version="1.0"?><rss><channel></channel></rss>))
      end

      request = HTTP::Request.new("GET", "/xml-content")
      client_response = call_request_on_app(request)
      client_response.body.should eq(%(<?xml version="1.0"?><rss><channel></channel></rss>))
    end

    it "accepts status_code parameter" do
      get "/xml-status" do |env|
        env.xml("<error>Bad Request</error>", status_code: 400)
      end

      request = HTTP::Request.new("GET", "/xml-status")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(400)
    end
  end

  describe "#status" do
    it "sets the response status code" do
      get "/status-only" do |env|
        env.status(204)
        ""
      end

      request = HTTP::Request.new("GET", "/status-only")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(204)
    end

    it "is chainable with json" do
      get "/status-json" do |env|
        env.status(201).json({id: 1, created: true})
      end

      request = HTTP::Request.new("GET", "/status-json")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(201)
      client_response.headers["Content-Type"].should eq("application/json")
      client_response.body.should eq(%({"id":1,"created":true}))
    end

    it "is chainable with html" do
      get "/status-html" do |env|
        env.status(404).html("<h1>Not Found</h1>")
      end

      request = HTTP::Request.new("GET", "/status-html")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(404)
      client_response.headers["Content-Type"].should eq("text/html; charset=utf-8")
    end

    it "is chainable with text" do
      get "/status-text" do |env|
        env.status(500).text("Internal Server Error")
      end

      request = HTTP::Request.new("GET", "/status-text")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(500)
      client_response.headers["Content-Type"].should eq("text/plain; charset=utf-8")
    end

    it "is chainable with xml" do
      get "/status-xml" do |env|
        env.status(400).xml("<error>Bad Request</error>")
      end

      request = HTTP::Request.new("GET", "/status-xml")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(400)
      client_response.headers["Content-Type"].should eq("application/xml; charset=utf-8")
    end
  end

  describe "#send" do
    it "auto-detects string as text/plain" do
      get "/send-string" do |env|
        env.send("Hello World")
      end

      request = HTTP::Request.new("GET", "/send-string")
      client_response = call_request_on_app(request)
      client_response.headers["Content-Type"].should eq("text/plain; charset=utf-8")
      client_response.body.should eq("Hello World")
    end

    it "auto-detects hash as application/json" do
      get "/send-hash" do |env|
        env.send({name: "test"})
      end

      request = HTTP::Request.new("GET", "/send-hash")
      client_response = call_request_on_app(request)
      client_response.headers["Content-Type"].should eq("application/json")
      client_response.body.should eq(%({"name":"test"}))
    end

    it "auto-detects array as application/json" do
      get "/send-array" do |env|
        env.send([1, 2, 3])
      end

      request = HTTP::Request.new("GET", "/send-array")
      client_response = call_request_on_app(request)
      client_response.headers["Content-Type"].should eq("application/json")
      client_response.body.should eq("[1,2,3]")
    end

    it "accepts status_code parameter for string" do
      get "/send-string-status" do |env|
        env.send("Created", status_code: 201)
      end

      request = HTTP::Request.new("GET", "/send-string-status")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(201)
    end

    it "accepts status_code parameter for hash" do
      get "/send-hash-status" do |env|
        env.send({error: "Not found"}, status_code: 404)
      end

      request = HTTP::Request.new("GET", "/send-hash-status")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(404)
    end

    it "is chainable with status" do
      get "/status-send" do |env|
        env.status(202).send({accepted: true})
      end

      request = HTTP::Request.new("GET", "/status-send")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(202)
      client_response.headers["Content-Type"].should eq("application/json")
    end
  end

  describe "real-world scenarios" do
    it "handles REST API create endpoint" do
      post "/api/users" do |env|
        env.status(201).json({id: 42, name: "Alice", created_at: "2024-01-01"})
      end

      request = HTTP::Request.new("POST", "/api/users")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(201)
      client_response.headers["Content-Type"].should eq("application/json")
    end

    it "handles REST API not found" do
      get "/api/users/999" do |env|
        env.status(404).json({error: "User not found", code: "USER_NOT_FOUND"})
      end

      request = HTTP::Request.new("GET", "/api/users/999")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(404)
      client_response.body.should contain("User not found")
    end

    it "handles validation error" do
      post "/api/validate" do |env|
        env.status(422).json({
          error:  "Validation failed",
          fields: {
            email: "is invalid",
            name:  "is required",
          },
        })
      end

      request = HTTP::Request.new("POST", "/api/validate")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(422)
      client_response.body.should contain("Validation failed")
    end

    it "handles health check endpoint" do
      get "/health" do |env|
        env.text("OK")
      end

      request = HTTP::Request.new("GET", "/health")
      client_response = call_request_on_app(request)
      client_response.status_code.should eq(200)
      client_response.body.should eq("OK")
    end

    it "handles RSS feed" do
      get "/feed.xml" do |env|
        env.xml(%(<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel><title>Blog</title></channel></rss>))
      end

      request = HTTP::Request.new("GET", "/feed.xml")
      client_response = call_request_on_app(request)
      client_response.headers["Content-Type"].should eq("application/xml; charset=utf-8")
      client_response.body.should contain("<rss")
    end
  end
end
