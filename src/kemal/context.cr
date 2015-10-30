# Context is the environment which holds request/response specific
# information such as params, content_type e.g
class Kemal::Context
  getter request
  getter response
  getter params
  getter content_type

  def initialize(@request, @params)
    @response = Kemal::Response.new
  end

  def headers
    @request.headers
  end

  def response_headers
    @response.headers
  end

  def set_header(name, value)
    @response.headers.add name, value
  end

  def content_type
    @response.content_type
  end

  def set_content_type(content_type)
    @response.content_type = content_type
  end

  delegate status_code, @response
end
