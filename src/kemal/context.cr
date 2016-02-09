# Context is the environment which holds request/response specific
# information such as params, content_type e.g
class HTTP::Server
  class Context
    getter params

    def params
      Kemal::ParamParser.new(@route, @request).parse
    end

    def redirect(url, status_code = 302)
      @response.headers.add "Location", url
      @response.status_code = status_code
    end
  end
end
