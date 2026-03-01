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
      alias StoreTypes = Union({{ STORE_MAPPINGS.splat }})
      @store = {} of String => StoreTypes
      @cached_route_lookup : Radix::Result(Kemal::Route)?
      @cached_ws_route_lookup : Radix::Result(Kemal::WebSocket)?
    end

    # Optimized: Use cached lookup results to avoid redundant route lookups
    # when params is accessed after route_found? or route has already been called
    def params
      ws_lookup = ws_route_lookup
      if ws_lookup.found?
        @params ||= Kemal::ParamParser.new(@request, ws_lookup.params)
      else
        @params ||= Kemal::ParamParser.new(@request, route_lookup.params)
      end
    end

    def redirect(url : String | URI, status_code : Int32 = 302, *, body : String? = nil, close : Bool = true)
      @response.headers.add "Location", url.to_s
      @response.status_code = status_code
      @response.print(body) if body
      @response.close if close
    end

    def route
      route_lookup.payload
    end

    def websocket
      ws_route_lookup.payload
    end

    # Optimized: Cache route lookup result to avoid redundant lookups
    # when called multiple times (e.g., route_found?, route, params)
    def route_lookup
      @cached_route_lookup ||= Kemal::RouteHandler::INSTANCE.lookup_route(@request.method.as(String), @request.path)
    end

    # Clears the cached route lookup and updates params with new route. Used by handlers that
    # modify the request (e.g. OverrideMethodHandler) so the next route lookup uses the updated request.
    def invalidate_route_cache
      @cached_route_lookup = nil
      params = @params
      if params
        new_lookup = Kemal::RouteHandler::INSTANCE.lookup_route(@request.method.as(String), @request.path)
        @cached_route_lookup = new_lookup
        params.update_url_params(new_lookup.params)
      end
    end

    def route_found?
      route_lookup.found?
    end

    # Optimized: Cache websocket route lookup result to avoid redundant lookups
    def ws_route_lookup
      @cached_ws_route_lookup ||= Kemal::WebSocketHandler::INSTANCE.lookup_ws_route(@request.path)
    end

    def ws_route_found?
      ws_route_lookup.found?
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

    # Sets the response status code and returns self for chaining.
    #
    # ```
    # get "/users/:id" do |env|
    #   if user = User.find?(env.params.url["id"])
    #     env.json(user)
    #   else
    #     env.status(404).json({error: "User not found"})
    #   end
    # end
    # ```
    def status(code : Int32) : self
      @response.status_code = code
      self
    end

    # Sets the response status from an *HTTP::Status* and returns self for chaining.
    #
    # ```
    # get "/users/:id" do |env|
    #   env.status(:not_found).json({error: "User not found"})
    # end
    #
    # post "/users" do |env|
    #   env.status(:created).json({id: 1})
    # end
    # ```
    def status(status : HTTP::Status) : self
      @response.status = status
      self
    end

    # Sends a JSON response with the proper `Content-Type` header.
    # Serializes the data to a string and writes it to the response in a single operation.
    # Use *content_type* for custom types (e.g. `application/vnd.api+json` for JSON API).
    #
    # ```
    # get "/users" do |env|
    #   env.json({users: ["alice", "bob"]})
    # end
    #
    # post "/users" do |env|
    #   env.status(201).json({created: true})
    # end
    #
    # # JSON API
    # get "/api/users" do |env|
    #   env.json({data: users}, content_type: "application/vnd.api+json")
    # end
    # ```
    def json(data, *, content_type : String = "application/json") : Nil
      @response.content_type = content_type
      @response << data.to_json
    end

    # Sends an HTML response with the proper `Content-Type` header.
    # Serializes the content to a string and writes it to the response in a single operation.
    #
    # ```
    # get "/" do |env|
    #   env.html("<h1>Welcome</h1>")
    # end
    # ```
    def html(content : String, *, content_type : String = "text/html; charset=utf-8") : Nil
      @response.content_type = content_type
      @response << content
    end

    # Sends a plain text response with the proper `Content-Type` header.
    # Serializes the content to a string and writes it to the response in a single operation.
    #
    # ```
    # get "/health" do |env|
    #   env.text("OK")
    # end
    # ```
    def text(content : String, *, content_type : String = "text/plain; charset=utf-8") : Nil
      @response.content_type = content_type
      @response << content
    end

    # Sends an XML response with the proper `Content-Type` header.
    # Serializes the content to a string and writes it to the response in a single operation.
    #
    # ```
    # get "/feed.xml" do |env|
    #   env.xml("<?xml version=\"1.0\"?><rss>...</rss>")
    # end
    # ```
    def xml(content : String, *, content_type : String = "application/xml; charset=utf-8") : Nil
      @response.content_type = content_type
      @response << content
    end
  end
end
