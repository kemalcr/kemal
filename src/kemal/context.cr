class Kemal::Context
  getter request
  getter params

  def initialize(@request, @params)
  end

  def response
    @response ||= Response.new
  end

  def response?
    @response
  end
end
