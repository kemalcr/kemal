# Exceptions for 404, 405 and custom errors are defined here.
module Kemal::Exceptions
  class InvalidPathStartException < Exception
    def initialize(method : String, path : String)
      super "Route declaration #{method} \"#{path}\" needs to start with '/', should be #{method} \"/#{path}\""
    end
  end

  # Raised when no route matches the request.
  #
  # The message is the bare status reason, as with `MethodNotAllowed`: an
  # `error 404` handler commonly returns `ex.message`, and the response is
  # `text/html`, so anything from the request in it would be reflected markup.
  # The request itself is reachable through `context`.
  class RouteNotFound < Exception
    getter context : HTTP::Server::Context

    def initialize(@context : HTTP::Server::Context)
      super "Not Found"
    end
  end

  # Raised when the request path is routed for at least one other HTTP method.
  #
  # [RFC 9110 §15.5.6](https://www.rfc-editor.org/rfc/rfc9110#section-15.5.6)
  # separates this from a `404`: the target resource exists, the method does not
  # apply to it. `allowed_methods` lists the methods that do, and
  # `Kemal::ExceptionHandler` renders it into the mandatory `Allow` response
  # header.
  class MethodNotAllowed < Exception
    getter context : HTTP::Server::Context
    getter allowed_methods : Array(String)

    # The message is the bare status reason because it doubles as the default
    # response body, and reflecting the request back into it would put
    # client-controlled text on the page. The request itself stays reachable
    # through `context`.
    def initialize(@context : HTTP::Server::Context, @allowed_methods : Array(String))
      super "Method Not Allowed"
    end
  end

  class CustomException < Exception
    def initialize(@context : HTTP::Server::Context, message : String? = nil)
      message ||= "Rendered error with #{context.response.status_code}"
      super message
    end
  end

  # Rendered as 413. The message is the response body, so it says which limit
  # fired but never what the request contained.
  class PayloadTooLarge < Exception
    def initialize(message : String = "Payload Too Large")
      super message
    end
  end

  # RFC 10008 requires QUERY request content to carry a media type.
  class InvalidQueryRequest < Exception
    def initialize
      super "QUERY request with a body requires a Content-Type header"
    end
  end

  # Raised when the framework itself cannot make sense of the request: a body it
  # cannot parse (broken JSON, unparseable multipart, from `ParamParser`), or a
  # request line it will not route (a method that is not an RFC 9110 token, from
  # `Kemal::MethodValidationHandler`). Rendered as 400. Only Kemal's own reading
  # of the request raises this, so a parse error inside handler code keeps its
  # original class and 500 status.
  class BadRequest < Exception
    def initialize(message : String? = nil, cause : Exception? = nil)
      super(message || "Bad Request", cause)
    end
  end
end
