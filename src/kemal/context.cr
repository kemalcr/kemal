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

  def response_headers
    @response.headers
  end

  def add_header(name, value)
    @response.headers.add name, value
  end

  def content_type
    @response.content_type
  end

  def redirect(url)
    @response.headers.add "Location", url
    @response.status_code = 301
  end

  delegate headers, @request
  delegate status_code, @response
  delegate :"status_code=", @response
  delegate :"content_type=", @response
end
