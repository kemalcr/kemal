require "kemal"

# This example demonstrates different ways to work with cookies in Kemal

# Route to set various types of cookies
get "/set-cookies" do |env|
  # Basic cookie with just name and value
  basic_cookie = HTTP::Cookie.new(
    name: "BasicCookie",
    value: "Hello from Kemal!"
  )

  # Secure cookie with additional security options
  secure_cookie = HTTP::Cookie.new(
    name: "SecureCookie",
    value: "Sensitive Data",
    http_only: true,                               # Cookie cannot be accessed via JavaScript
    secure: true,                                  # Cookie only sent over HTTPS
    path: "/",                                     # Cookie available for all paths
    expires: Time.local + Time::Span.new(days: 7), # Cookie expires in 7 days
    samesite: HTTP::Cookie::SameSite::Strict       # Never sent on cross-site requests (CSRF)
  )

  # Session cookie that expires when browser closes
  session_cookie = HTTP::Cookie.new(
    name: "SessionCookie",
    value: "Temporary",
    http_only: true,
    samesite: HTTP::Cookie::SameSite::Lax # Cross-site, sent only on top-level GET navigation
  )

  # Add all cookies to response
  env.response.cookies << basic_cookie
  env.response.cookies << secure_cookie
  env.response.cookies << session_cookie

  "Cookies have been set! Visit /show-cookies to view them."
end

# Route to display current cookies
get "/show-cookies" do |env|
  cookies = env.request.cookies
  response = String.build do |str|
    str << "<h1>Current Cookies:</h1>"
    str << "<ul>"
    cookies.each do |cookie|
      # Cookies are client-controlled: escape them before writing HTML
      str << "<li>#{HTML.escape(cookie.name)}: #{HTML.escape(cookie.value)}</li>"
    end
    str << "</ul>"
  end
  response
end

# Route to delete a specific cookie
# Use a non-GET method for state changes so links and prefetches cannot trigger it
delete "/cookies/:name" do |env|
  cookie_name = env.params.url["name"]

  begin
    # The path must match the cookie's path, or the browser keeps it
    delete_cookie = HTTP::Cookie.new(cookie_name, "", path: "/")
  rescue IO::Error # HTTP::Cookie rejects names that are not valid cookie tokens
    env.response.status_code = 400
    next "Invalid cookie name"
  end

  # `expire` sets Max-Age=0, which deletes the cookie whatever the client's clock says
  delete_cookie.expire
  env.response.cookies << delete_cookie
  "Cookie '#{HTML.escape(cookie_name)}' has been deleted!"
end

Kemal.run
