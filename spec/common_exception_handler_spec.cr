require "./spec_helper"

describe "Kemal::CommonExceptionHandler" do
  it "renders 404 on route not found" do
    common_exception_handler = Kemal::CommonExceptionHandler::INSTANCE
    request = HTTP::Request.new("GET", "/?message=world")
    io_with_context = create_request_and_return_io(common_exception_handler, request)
    client_response = HTTP::Client::Response.from_io(io_with_context, decompress: false)
    client_response.status_code.should eq 404
  end
end
