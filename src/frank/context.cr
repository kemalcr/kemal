class Frank::Context
  getter request

  def initialize(@request)
  end

  def response
    @response ||= Response.new
  end

  def response?
    @response
  end
end
