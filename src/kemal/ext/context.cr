# HTTP::Server::Context is the class which holds HTTP::Request and HTTP::Server::Response alongside with
# information such as request params, request/response content_type, session e.g
#
# Instances of this class are passed to an `HTTP::Server` handler.
class HTTP::Server
  class Context
    # :nodoc:
    STORE_MAPPINGS = [Nil, String, Int32, Int64, Float64, Bool]

    def initialize(@request : Request, @response : Response)
      @param_parser = if @request.param_parser
                        @request.param_parser.not_nil!
                      else
                        Kemal::ParamParser.new(@request.not_nil!)
                      end
      @request.url_params ||= route_lookup.params
      @param_parser.parse
    end

    macro finished
      alias StoreTypes = Union({{ *STORE_MAPPINGS }})
      getter store = {} of String => StoreTypes
    end

    def params
      @param_parser.params
    end

    def files
      @param_parser.files
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
