macro redirect(url)
  env.response.headers.add "Location", {{url}}
  env.response.status_code = 301
end