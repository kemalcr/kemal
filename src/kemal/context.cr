# Context is the environment which holds request/response specific
# information such as params, content_type e.g
class HTTP::Server
  class Context
    alias StoreTypes =  Nil | String | Int32 | Float64 | Bool
    getter store = {} of String => StoreTypes

    def params
      @request.url_params ||= route_lookup.params
      @params ||= Kemal::ParamParser.new(@request)
    end

    def redirect(url, status_code = 302)
      @response.headers.add "Location", url
      @response.status_code = status_code
    end

    def route_lookup
      Kemal::RouteHandler::INSTANCE.lookup_route(@request.override_method.as(String), @request.path)
    end

    def route_defined?
      route_lookup.found?
    end

    def session
      @session ||= Kemal::Sessions.new(self)
      @session.not_nil!
    end

    def get(name)
      @store[name]
    end

    def set(name, value)
      @store[name] = value
    end
  end
end
