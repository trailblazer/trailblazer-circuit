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
        def self.call(node, ctx, lib_ctx, signal, **circuit_options)
          node.(ctx, lib_ctx, signal, **circuit_options) # NOTE: runner calls node with the circuit interface.
        end
      end
    end
  end # Circuit
end
