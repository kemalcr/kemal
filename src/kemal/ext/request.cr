class HTTP::Request
  property url_params : Hash(String, String)?

  def content_type
    @headers["Content-Type"]?
  end
end
