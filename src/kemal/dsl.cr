HTTP_METHODS = %w(get post put patch delete)

{% for method in HTTP_METHODS %}
  def {{method.id}}(path, &block : Kemal::Context -> _)
   Kemal::Handler::INSTANCE.add_route({{method}}.upcase, path, &block)
  end
{% end %}
