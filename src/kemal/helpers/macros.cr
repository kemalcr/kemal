# `content_for` is a set of helpers that allows you to capture
# blocks inside views to be rendered later during the request. The most
# common use is to populate different parts of your layout from your view.
#
# The currently supported engines are: ecr and slang.
#
# ## Usage
#
# You call `content_for`, generally from a view, to capture a block of markup
# giving it an identifier:
#
# ```
# # index.ecr
# <% content_for "some_key" do %>
#   <chunk of="html">...</chunk>
# <% end %>
# ```
#
# Then, you call `yield_content` with that identifier, generally from a
# layout, to render the captured block:
#
# ```
# # layout.ecr
# <%= yield_content "some_key" %>
# ```
#
# ## And How Is This Useful?
#
# For example, some of your views might need a few javascript tags and
# stylesheets, but you don't want to force this files in all your pages.
# Then you can put `<%= yield_content :scripts_and_styles %>` on your
# layout, inside the <head> tag, and each view can call `content_for`
# setting the appropriate set of tags that should be added to the layout.
#
# Captured blocks live in `__content_for_blocks__`, a local that
# `render(view, layout)` declares, so they belong to the one render call that
# captured them: two requests rendering the same view concurrently cannot see
# each other's blocks. Both macros are therefore only usable inside a
# `render(view, layout)` call, directly in the view or in a partial it renders.
macro content_for(key)
  __content_for_blocks__[{{ key }}] = ->() { {{ yield }}; nil }
  nil
end

# Yields content for the given key if a `content_for` block exists for that key.
#
# The captured block was compiled to write into `content_io`, the view's output,
# so it is pointed at a fresh buffer for the duration of the call and put back
# afterwards; the buffer is what the layout receives.
macro yield_content(key)
  if %proc = __content_for_blocks__[{{ key }}]?
    %old_content_io, content_io = content_io, IO::Memory.new
    %proc.call
    %result = content_io.to_s
    content_io = %old_content_io
    %result
  end
end

# Render view with a layout as the superview.
#
# ```
# render "src/views/index.ecr", "src/views/layout.ecr"
# ```
macro render(filename, layout)
  __content_for_blocks__ = {} of String => Proc(Nil)
  content_io = IO::Memory.new
  ECR.embed {{ filename }}, content_io
  content = content_io.to_s
  layout_io = IO::Memory.new
  ECR.embed {{ layout }}, layout_io
  layout_io.to_s
end

# Render view with the given filename.
macro render(filename)
  ECR.render({{ filename }})
end

# Halts execution by closing the response. Designed for use with chained response method calls.
#
# ```
# # Example: Send a JSON error and halt immediately
# halt env.status(500).json({error: "Internal Server Error"})
#
# # Example: Immediately close and halt after rendering HTML
# halt env.status(403).html("Forbidden")
# ```
#
# NOTE: For most cases that require setting a specific status code and body, prefer the alternative:
#
# ```
# halt env, status_code: 403, response: "Forbidden"
# ```
macro halt(response)
  {% if response.is_a?(Call) && response.receiver %}
    %env = {{ response.receiver }}
    {{ response }}
    %env.response.close
    next
  {% else %}
    {{ response }}.response.close
    next
  {% end %}
end

# Halt execution with the current context.
# Returns 200 and an empty response by default.
#
# ```
# halt env, status_code: 403, response: "Forbidden"
# ```
macro halt(env, status_code = 200, response = "")
  {{ env }}.response.status_code = {{ status_code }}
  {{ env }}.response.print {{ response }}
  {{ env }}.response.close
  next
end

# Extends context storage with user defined types.
#
# ```
# class User
#   property name
# end
#
# add_context_storage_type(User)
# ```
macro add_context_storage_type(type)
  {{ HTTP::Server::Context::STORE_MAPPINGS.push(type) }}
end
