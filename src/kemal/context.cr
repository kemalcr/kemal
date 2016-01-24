# Context is the environment which holds request/response specific
# information such as params, content_type e.g
class HTTP::Server
  class Context
    getter params

    def params
      Kemal::ParamParser.new(@route, @request).parse
    end

    def redirect(url)
      @response.headers.add "Location", url
      @response.status_code = 301
    end
  end
end
