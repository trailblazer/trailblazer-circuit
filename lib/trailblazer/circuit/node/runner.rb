 module Trailblazer
  class Circuit
    # This is the only overridable part of Processor where we know,
    # at runtime, what is the next step.
    class Node
      # A Runner is called in {Circuit::Processor.call} to process and
      # run a task (which is part of a node).
      #
      # Runner currently simply delegates to "scope" (formerly Node::Processor but the name sucks.)
      # It automatically merges "scoping options/configuration" at runtime, so this can be extended, too
      # (e.g. for tracing).
      class Runner
        def initialize(**options)
          @options = options
        end

        def [](key)
          @options[key]
        end

        def merge(**options)
          self.class.new(**@options.merge(options))
        end

        def reverse_merge(**options)
          merge(**options.merge(@options))
        end

        def to_h
          @options
        end

        def fetch(key)
          @options.fetch(key)
        end

        def call(lib_ctx, flow_options, signal, node, _id)
          node.(lib_ctx, flow_options, signal)
        end
      end
    end
  end # Circuit
end
