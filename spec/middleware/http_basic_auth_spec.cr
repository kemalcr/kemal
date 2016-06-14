require "../spec_helper"

describe "Kemal::Middleware::HTTPBasicAuth" do
  it "goes to next handler with correct credentials" do
    auth_handler = Kemal::Middleware::HTTPBasicAuth.new("serdar", "123")
    request = HTTP::Request.new(
      "GET",
      "/",
      headers: HTTP::Headers{"Authorization" => "Basic c2VyZGFyOjEyMw=="},
    )

    io_with_context = create_request_and_return_io(auth_handler, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.status_code.should eq 404
  end

  it "returns 401 with incorrect credentials" do
    auth_handler = Kemal::Middleware::HTTPBasicAuth.new("serdar", "123")
    request = HTTP::Request.new(
      "GET",
      "/",
      headers: HTTP::Headers{"Authorization" => "NotBasic"},
    )
    io_with_context = create_request_and_return_io(auth_handler, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.status_code.should eq 401
  end
end
