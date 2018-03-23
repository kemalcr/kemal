require "../spec_helper"

describe Kemal::Etag do
  describe ".add_header" do
    it "adds Etag header to headers" do
      headers = HTTP::Headers.new
      Kemal::Etag.add_header(headers, "new-etag")
      headers["Etag"].should eq "new-etag"
    end
  end

  describe ".matches?" do
    it "returns false if If-None-Match is not included" do
      headers = HTTP::Headers.new
      Kemal::Etag.matches?(headers, "request-etag").should be_false
    end

    it "returns false where etag differs" do
      headers = HTTP::Headers{"If-None-Match" => "different etag"}
      Kemal::Etag.matches?(headers, "request-etag").should be_false
    end

    it "returns true on a match" do
      headers = HTTP::Headers{"If-None-Match" => "request-etag"}
      Kemal::Etag.matches?(headers, "request-etag").should be_true
    end
  end

  describe ".from_file" do
    it "returns etag based on file's mtime" do
      file_path = "#{__DIR__}/../static/dir/test.txt"
      Kemal::Etag.from_file(file_path).should match(/W\/"\d+"$/)
    end
  end

  describe ".set_not_modified" do
    it "removes content type header" do
      response = HTTP::Server::Response.new(IO::Memory.new)
      response.content_type = "content-type"

      response.headers["Content-Type"]?.should_not be_nil
      Kemal::Etag.set_not_modified(response)
      response.headers["Content-Type"]?.should be_nil
    end

    it "sets content length to 0" do
      response = HTTP::Server::Response.new(IO::Memory.new)
      response.content_length = 42

      response.headers["Content-Length"].should eq("42")
      Kemal::Etag.set_not_modified(response)
      response.headers["Content-Length"].should eq("0")
    end

    it "sets status code to NotModified" do
      response = HTTP::Server::Response.new(IO::Memory.new)
      response.status_code = 200

      Kemal::Etag.set_not_modified(response)
      response.status_code.should eq 304
    end
  end
end
