module Kemal
  # Refuses a request whose method is not an [RFC 9110 §5.6.2](https://www.rfc-editor.org/rfc/rfc9110#section-5.6.2)
  # token, before anything routes it or stands in front of it.
  #
  # Crystal's request parser takes whatever bytes stand before the first space of
  # the request line as the method, without validating them, and Kemal keys its
  # routing tree on the method concatenated with the path. A method holding a `/`
  # therefore moves the boundary between the two: `GET/admin` + `/secret` produces
  # the same key as `GET` + `/admin/secret` and reaches the same route, while the
  # guards in front of that route - `use "/prefix"`, `only`/`exclude`,
  # `before_*`/`after_*` - all match on `request.path` and see only `/secret`
  # (#820).
  #
  # Sits behind `Kemal::ExceptionHandler` and the log handler, so the refusal is
  # rendered by a registered `error 400` and written to the access log like any
  # other client error, and ahead of the static file handler, the custom handlers
  # and the filters, none of which should ever see a method that means two things.
  # With `always_rescue = false` there is no exception handler to render it and the
  # `Kemal::Exceptions::BadRequest` leaves Kemal, exactly as a `RouteNotFound`
  # does; the request is refused either way.
  class MethodValidationHandler
    include HTTP::Handler

    INSTANCE = new

    def call(context : HTTP::Server::Context)
      unless Utils.valid_method?(context.request.method)
        # The connection does not get to carry another request. A request line
        # Kemal reads one way and an intermediary in front of it reads another is
        # exactly the parsing disagreement request smuggling is built on
        # (RFC 9112 §11.2), so the stream ends here rather than staying open for
        # whatever the peer believes it already sent. `close` is the signal for
        # that (RFC 9112 §9.6), and it survives a custom `error 400`, which
        # `Kemal::ExceptionHandler` dispatches without touching response headers.
        context.response.headers["Connection"] = "close"
        raise Kemal::Exceptions::BadRequest.new
      end

      call_next context
    end
  end
end
