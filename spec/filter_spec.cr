require "./spec_helper"

describe "Kemal::FilterHandler" do
  it "handles with downcased 'post'" do
    before_post do |env|
      env.set "sensitive", "1"
    end

    post "/sensitive_post" do |env|
      env.get "sensitive"
    end

    # For some reason somewhere in `Spec.after_each` handler,
    # `call_request_on_app()` doesn't work with sequentially called specs:
    # only one test can be passed for the same time.
    # Use this sequence instead
    request = HTTP::Request.new("post", "/sensitive_post")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::FilterHandler::INSTANCE.call(context)
    Kemal::RouteHandler::INSTANCE.call(context)

    context.get("sensitive").should eq "1"
  end

  it "handles with upcased 'POST'" do
    before_post do |env|
      env.set "sensitive", "1"
    end

    post "/sensitive_post" do |env|
      env.get "sensitive"
    end

    # For some reason somewhere in `Spec.after_each` handler,
    # `call_request_on_app()` doesn't work with sequentially called specs:
    # only one test can be passed for the same time.
    # Use this sequence instead
    request = HTTP::Request.new("POST", "/sensitive_post")
    io = IO::Memory.new
    response = HTTP::Server::Response.new(io)
    context = HTTP::Server::Context.new(request, response)
    Kemal::FilterHandler::INSTANCE.call(context)
    Kemal::RouteHandler::INSTANCE.call(context)

    context.get("sensitive").should eq "1"
  end
end
