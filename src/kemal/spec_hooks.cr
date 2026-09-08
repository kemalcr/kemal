module Kemal
  # Kemal's top-level `before_all` and `after_all` share their names with the
  # `describe`-level hooks of Crystal's `spec` library, and as top-level
  # definitions they shadow them. A spec that calls `before_all` inside a
  # `describe` reaches Kemal, which would register a request filter and never
  # run the block - silently. `before_all` and `after_all` therefore hand a call
  # made inside a `describe` back to the spec library through here.
  #
  # `Spec::Context`'s hooks are protected and reachable only from inside the
  # `Spec` namespace, so the bridge lives there. It is defined in a `finished`
  # hook so that it exists whenever the program loads `spec`, whichever of
  # `spec` and `kemal` is required first.
  macro finished
    {% if @top_level.has_constant?("Spec") %}
      module ::Spec
        # :nodoc:
        module KemalHooks
          def self.before_all(&block : ->) : Nil
            Spec.cli.current_context.before_all(&block)
          end

          def self.after_all(&block : ->) : Nil
            Spec.cli.current_context.after_all(&block)
          end
        end
      end
    {% end %}
  end
end
