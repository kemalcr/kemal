class Kemal::Request
  getter params

  def initialize(@request, @params)
  end

  delegate body, @request
end
