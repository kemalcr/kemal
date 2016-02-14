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

    def filter_for_path_type_defined?(path, type)
      lookup = @tree.find radix_path(type, path)
      lookup.found? && lookup.payload.is_a? Block
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

    class BeforeFilterAlreadyDefinedException < Exception
      def initialize(path)
        super "A before-filter is already defined for path: '#{path}'."
      end
    end

    class AfterFilterAlreadyDefinedException < Exception
      def initialize(path)
        super "An after-filter is already defined for path: '#{path}'."
      end
    end
  end

  class Block
    property block

    def initialize(&@block : HTTP::Server::Context -> _)
    end
  end
end

def add_filters
  unless filter = Kemal.config.handlers.any? { |handler| handler.is_a? Kemal::Middleware::Filter }
    filter = Kemal::Middleware::Filter.new
    Kemal.config.add_handler filter
  end
  filter
end

def before(path = "*", options = {} of Symbol => String, &block : HTTP::Server::Context -> _)
  filter = (Kemal.config.handlers.find { |handler| handler.is_a? Kemal::Middleware::Filter } || add_filters) as Kemal::Middleware::Filter
  raise Kemal::Middleware::Filter::BeforeFilterAlreadyDefinedException.new(path) if filter.filter_for_path_type_defined?(path, :before)
  filter.add :before, path, options, &block
end

def after(path = "*", options = {} of Symbol => String, &block : HTTP::Server::Context -> _)
  filter = (Kemal.config.handlers.find { |handler| handler.is_a? Kemal::Middleware::Filter } || add_filters) as Kemal::Middleware::Filter
  raise Kemal::Middleware::Filter::AfterFilterAlreadyDefinedException.new(path) if filter.filter_for_path_type_defined?(path, :after)
  filter.add :after, path, options, &block
end
