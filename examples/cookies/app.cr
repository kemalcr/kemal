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
    http_only: true,                              # Cookie cannot be accessed via JavaScript
    secure: true,                                 # Cookie only sent over HTTPS
    path: "/",                                    # Cookie available for all paths
    expires: Time.local + Time::Span.new(days: 7) # Cookie expires in 7 days
  )

  # Session cookie that expires when browser closes
  session_cookie = HTTP::Cookie.new(
    name: "SessionCookie",
    value: "Temporary",
    http_only: true
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
      str << "<li>#{cookie.name}: #{cookie.value}</li>"
    end
    str << "</ul>"
  end
  response
end

# Route to delete a specific cookie
get "/delete-cookie/:name" do |env|
  cookie_name = env.params.url["name"]

  # Set cookie with immediate expiration to delete it
  delete_cookie = HTTP::Cookie.new(
    name: cookie_name,
    value: "",
    expires: Time.local - 1.day
  )

  env.response.cookies << delete_cookie
  "Cookie '#{cookie_name}' has been deleted!"
end

Kemal.run
