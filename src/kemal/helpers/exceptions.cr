# Exceptions for 404, 405 and custom errors are defined here.
module Kemal::Exceptions
  class InvalidPathStartException < Exception
    def initialize(method : String, path : String)
      super "Route declaration #{method} \"#{path}\" needs to start with '/', should be #{method} \"/#{path}\""
    end
  end

  class RouteNotFound < Exception
    def initialize(context : HTTP::Server::Context)
      super "Requested path: '#{context.request.method}:#{context.request.path}' was not found."
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
    getter allowed_methods : Array(String)

    # *context* mirrors `RouteNotFound` so both routing failures are raised the
    # same way. The message is the bare status reason because it doubles as the
    # default response body, and reflecting the request back into it would put
    # client-controlled text on the page.
    def initialize(context : HTTP::Server::Context, @allowed_methods : Array(String))
      super "Method Not Allowed"
    end
  end

  class CustomException < Exception
    def initialize(@context : HTTP::Server::Context, message : String? = nil)
      message ||= "Rendered error with #{context.response.status_code}"
      super message
    end
  end

  class PayloadTooLarge < Exception
    def initialize
      super "Payload Too Large"
    end
  end

  # RFC 10008 requires QUERY request content to carry a media type.
  class InvalidQueryRequest < Exception
    def initialize
      super "QUERY request with a body requires a Content-Type header"
    end
  end

  # Raised by `ParamParser` when the framework cannot parse the request body
  # (broken JSON, unparseable multipart). Rendered as 400. Only wraps failures
  # from Kemal's own body parsing, so a parse error inside handler code keeps
  # its original class and 500 status.
  class BadRequest < Exception
    def initialize(message : String? = nil, cause : Exception? = nil)
      super(message || "Bad Request", cause)
    end
  end
end
