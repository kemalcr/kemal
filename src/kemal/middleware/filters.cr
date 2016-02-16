module Kemal::Middleware
  # Kemal::Filter handle all code that should be evaluated before and after
  # every request
  class Filter < HTTP::Handler
    def initialize
      @tree = Radix::Tree.new
    end

    def add(verb, path, type, &block : HTTP::Server::Context -> _)
      node = radix_path(verb, path, type)
      @tree.add node, Block.new &block
    end

    def call(context)
      process_filter(context, :before)
      call_next(context)
      process_filter(context, :after)
    end

    def filter_for_path_type_defined?(verb, path, type)
      lookup = @tree.find radix_path(verb, path, type)
      lookup.found? && lookup.payload.is_a? Block
    end

    private def process_filter(context, type)
      Kemal::Route.check_for_method_override!(context.request)
      lookup = @tree.find radix_path(context.request.override_method, context.request.path, type)
      if lookup.found? && lookup.payload.is_a? Block
        block = lookup.payload as Block
        block.block.call(context)
      end
    end

    private def radix_path(verb, path, type : Symbol)
      "#{type}/#{verb}/#{path}"
    end

    class BeforeFilterAlreadyDefinedException < Exception
      def initialize(verb, path)
        super "A before-filter is already defined for path: '#{verb}:#{path}'."
      end
    end

    class AfterFilterAlreadyDefinedException < Exception
      def initialize(verb, path)
        super "An after-filter is already defined for path: '#{verb}:#{path}'."
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

def before(verb, path = "*", &block : HTTP::Server::Context -> _)
  filter = (Kemal.config.handlers.find { |handler| handler.is_a? Kemal::Middleware::Filter } || add_filters) as Kemal::Middleware::Filter
  raise Kemal::Middleware::Filter::BeforeFilterAlreadyDefinedException.new(verb, path) if filter.filter_for_path_type_defined?(verb, path, :before)
  filter.add verb, path, :before, &block
end

def after(verb, path = "*", &block : HTTP::Server::Context -> _)
  filter = (Kemal.config.handlers.find { |handler| handler.is_a? Kemal::Middleware::Filter } || add_filters) as Kemal::Middleware::Filter
  raise Kemal::Middleware::Filter::AfterFilterAlreadyDefinedException.new(verb, path) if filter.filter_for_path_type_defined?(verb, path, :after)
  filter.add verb, path, :after, &block
end
