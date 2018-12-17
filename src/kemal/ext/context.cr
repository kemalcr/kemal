# `HTTP::Server::Context` is the class which holds `HTTP::Request` and
# `HTTP::Server::Response` alongside with information such as request params,
# request/response content_type, session data and alike.
#
# Instances of this class are passed to an `HTTP::Server` handler.
class HTTP::Server
  class Context
    # :nodoc:
    STORE_MAPPINGS = [Nil, String, Int32, Int64, Float64, Bool]

    macro finished
      alias StoreTypes = Union({{ *STORE_MAPPINGS }})
      getter store = {} of String => StoreTypes
    end

    def params
      @params ||= Kemal::ParamParser.new(@request)
    end

    def redirect(url : String, status_code : Int32 = 302)
      @response.headers.add "Location", url
      @response.status_code = status_code
    end

    def get(name : String)
      @store[name]
    end

    def set(name : String, value : StoreTypes)
      @store[name] = value
    end

    def get?(name : String)
      @store[name]?
    end
  end
end
