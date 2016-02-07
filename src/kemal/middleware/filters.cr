module Kemal::Middleware
  # Kemal::Filter handle all code that should be evaluated before and after
  # every request
  class Filter < HTTP::Handler
    def initialize
      @tree = Radix::Tree.new
    end

    def add(type, path, options, &block : HTTP::Server::Context -> _)
      node = radix_path type, path
      @tree.add node, Block.new &block
    end

    def call(context)
      process_filter(context, :before)
      call_next(context)
      process_filter(context, :after)
    end

    private def process_filter(context, type)
      lookup = @tree.find radix_path(type, context.request.path)
      if lookup.found? && lookup.payload.is_a? Block
        block = lookup.payload as Block
        block.block.call(context)
      end
    end

    private def radix_path(type : Symbol, path)
      "/#{type}#{path}"
    end
  end

  class Block
    property block
    def initialize(&@block : HTTP::Server::Context -> _)
    end
  end
end

def add_filters
  Kemal.config.add_handler Kemal::Middleware::Filter.new
end

def before(path = "*", options = {} of Symbol => String, &block : HTTP::Server::Context -> _)
  filter = Kemal.config.handlers.first as Kemal::Middleware::Filter
  filter.add :before, path, options, &block
end

def after(path = "*", options = {} of Symbol => String, &block : HTTP::Server::Context -> _)
  filter = Kemal.config.handlers.first as Kemal::Middleware::Filter
  filter.add :after, path, options, &block
end
