require "kilt"

CONTENT_FOR_BLOCKS = Hash(String, Proc(String)).new

# <tt>content_for</tt> is a set of helpers that allows you to capture
# blocks inside views to be rendered later during the request. The most
# common use is to populate different parts of your layout from your view.
#
# The currently supported engines are: ecr and slang.
#
# == Usage
#
# You call +content_for+, generally from a view, to capture a block of markup
# giving it an identifier:
#
#     # index.ecr
#     <% content_for "some_key" do %>
#       <chunk of="html">...</chunk>
#     <% end %>
#
# Then, you call +yield_content+ with that identifier, generally from a
# layout, to render the captured block:
#
#     # layout.ecr
#     <%= yield_content "some_key" %>
#
# == And How Is This Useful?
#
# For example, some of your views might need a few javascript tags and
# stylesheets, but you don't want to force this files in all your pages.
# Then you can put <tt><%= yield_content :scripts_and_styles %></tt> on your
# layout, inside the <head> tag, and each view can call <tt>content_for</tt>
# setting the appropriate set of tags that should be added to the layout.
macro content_for(key)
  CONTENT_FOR_BLOCKS[{{key}}] = ->() {
    __kilt_io__ = MemoryIO.new
    {{ yield }}
    __kilt_io__.to_s
  }
  nil
end

macro yield_content(key)
  CONTENT_FOR_BLOCKS[{{key}}].call
end

macro render(filename, layout)
  content = render {{filename}}
  render {{layout}}
end

macro render(filename, *args)
  Kilt.render({{filename}}, {{*args}})
end

macro return_with(env, status_code = 200, response = "")
  {{env}}.response.status_code = {{status_code}}
  {{env}}.response.print {{response}}
  next
end

# Adds given HTTP::Handler+ to handlers.
def add_handler(handler)
  Kemal.config.add_handler handler
end

# Uses Kemal::Middleware::HTTPBasicAuth to easily add HTTP Basic Auth support.
def basic_auth(username, password)
  auth_handler = Kemal::Middleware::HTTPBasicAuth.new(username, password)
  add_handler auth_handler
end

# Sets public folder from which the static assets will be served.
# By default this is `/public` not `src/public`.
def public_folder(path)
  Kemal.config.public_folder = path
end

# Logs to output stream.
# development: STDOUT in
# production: kemal.log
def log(message)
  Kemal.config.logger.write "#{message}\n"
end

# Enables / Disables logging
def logging(status)
  Kemal.config.logging = status
end

def logger(logger)
  Kemal.config.logger = logger
  Kemal.config.add_handler logger
end

def serve_static(status)
  Kemal.config.serve_static = status
end

def headers(env, additional_headers)
  env.response.headers.merge!(additional_headers)
end
