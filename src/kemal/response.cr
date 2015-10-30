class Kemal::Response
  property headers
  property status_code
  property content_type

  def initialize
    @status_code :: String
    @content_type = "text/html"
    @headers = HTTP::Headers{"Content-Type": @content_type}
  end

  def content_type=(content_type)
    @headers["Content-Type"] = content_type
  end
end
