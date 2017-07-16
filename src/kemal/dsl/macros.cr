def content_for_blocks
  Kemal.application.content_for_blocks
end

macro content_for(key, file = __FILE__)
  Kemal::Macros.content_for({{key}}, {{file}}) do
    {{yield}}
  end
end

# Yields content for the given key if a `content_for` block exists for that key.
macro yield_content(key)
  Kemal::Macros.yield_content({{key}})
end

# Render view with a layout as the superview.
#
#   render "src/views/index.ecr", "src/views/layout.ecr"
#
macro render(filename, layout)
  Kemal::Macros.render({{filename}}, {{layout}})
end

# Render view with the given filename.
macro render(filename)
  Kemal::Macros.render({{filename}})
end

# Halt execution with the current context.
# Returns 200 and an empty response by default.
#
#   halt env, status_code: 403, response: "Forbidden"
macro halt(env, status_code = 200, response = "")
  Kemal::Macros.halt({{env}}, {{status_code}}, {{response}})
end

# Extends context storage with user defined types.
#
# class User
#   property name
# end
#
# add_context_storage_type(User)
#
macro add_context_storage_type(type)
  Kemal::Macros.add_context_storage_type({{type}})
end
