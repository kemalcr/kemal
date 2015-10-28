class Kemal::Context
  getter request
  getter params
  getter content_type

  def initialize(@request, @params)
    @content_type = "text/plain"
  end

  def set_content_type(content_type)
    @content_type = content_type
  end
end
