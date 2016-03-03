# Context is the environment which holds request/response specific
# information such as params, content_type e.g
class HTTP::Server
  class Context
    def params
      @request.url_params = route_lookup.params
      @params ||= Kemal::ParamParser.new(@request).parse
    end

   def redirect(url, status_code = 302)
      @response.headers.add "Location", url
      @response.status_code = status_code
    end

    def route_lookup
      @route_lookup ||= Kemal::RouteHandler::INSTANCE.lookup_route(@request.override_method as String, @request.path)
    end

    def route_defined?
      route_lookup.found?
    end

    def clear_session
      @session = {} of String => String
    end

    def session
      @session ||= {} of String => String
    end

  end
end
