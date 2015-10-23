class Kemal::Context
  getter request

  def initialize(@request)
  end

  def response
    @response ||= Response.new
  end

  def response?
    @response
  end

  def params
    request.params
  end
end
