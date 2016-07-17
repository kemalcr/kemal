require "secure_random"

module Kemal::Middleware
  # This middleware adds CSRF protection to your application.
  #
  # Returns 403 "Forbidden" unless the current CSRF token is submitted
  # with any non-GET/HEAD request.
  #
  # Without CSRF protection, your app is vulnerable to replay attacks
  # where an attacker can re-submit a form.
  #
  class CSRF < HTTP::Handler
    HEADER          = "X_CSRF_TOKEN"
    ALLOWED_METHODS = %w(GET HEAD OPTIONS TRACE)
    PARAMETER_NAME  = "authenticity_token"

    def call(context)
      unless context.session["csrf"]?
        context.session["csrf"] = SecureRandom.hex(16)
      end

      return call_next(context) if ALLOWED_METHODS.includes?(context.request.method)

      req = context.request
      submitted = if req.headers[HEADER]?
                    req.headers[HEADER]
                  elsif context.params.body[PARAMETER_NAME]?
                    context.params.body[PARAMETER_NAME]
                  else
                    "nothing"
                  end
      current_token = context.session["csrf"]

      if current_token == submitted
        # reset the token so it can't be used again
        context.session["csrf"] = SecureRandom.hex(16)
        return call_next(context)
      else
        context.response.status_code = 403
        context.response.print "Forbidden"
      end
    end
  end
end
