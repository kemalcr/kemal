require "kilt"

CONTENT_FOR_BLOCKS = Hash(String, Tuple(String, Proc(String))).new

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
macro content_for(key, file = __FILE__)
  %proc = ->() {
    __kilt_io__ = MemoryIO.new
    {{ yield }}
    __kilt_io__.to_s
  }

  CONTENT_FOR_BLOCKS[{{key}}] = Tuple.new {{file}}, %proc
  nil
end

macro yield_content(key)
  if CONTENT_FOR_BLOCKS.has_key?({{key}})
    __caller_filename__ = CONTENT_FOR_BLOCKS[{{key}}][0]
    %proc = CONTENT_FOR_BLOCKS[{{key}}][1]
    %proc.call if __content_filename__ == __caller_filename__
  end
end

macro render(filename, layout)
  __content_filename__ = {{filename}}
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
