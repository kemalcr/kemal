# HTTP::Server::Context is the class which holds HTTP::Request and HTTP::Server::Response alongside with
# information such as request params, request/response content_type, session e.g
#
# Instances of this class are passed to an `HTTP::Server` handler.
class HTTP::Server
  class Context
    # :nodoc:
    STORE_MAPPINGS = [ Nil, String, Int32, Int64, Float64, Bool ]

    macro finished
      alias StoreTypes = Union({{ *STORE_MAPPINGS }})
      getter store = {} of String => StoreTypes
    end

    def params
      @request.url_params ||= route_lookup.params
      @params ||= if @request.param_parser
                    @request.param_parser.not_nil!
                  else
                    Kemal::ParamParser.new(@request)
                  end
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

    def get(name)
      @store[name]
    end

    def set(name, value)
      @store[name] = value
    end
  end
end
