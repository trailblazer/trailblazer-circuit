# This is an optional feature.
module Trailblazer
  class Circuit
    # WrapRuntime is a historical term. This feature allows to, at run-time,
    # alter the currently processed node, meaning you can extend a pipeline/circuit
    # (for example to add tracing steps), or change other node attributes like the
    # processor.
    #
    # NOTE: currently, only the Adds interface is public (see Extension).
    module WrapRuntime
      # for every node, calls a resolver
      # that resolver might return a list of extensions
      # those extensions are then built at runtime
      #

      # This Runner is passed via circuit_options's :runner kwarg. It extends the original
      # runner and extends pipelines throuh the configured {Extension}s.
      #
      # The extensions are looked up via a resolver in circuit_options[:wrap_runtime].
      #
      # DISCUSS: in this "pure" implementation it is completely up to the extensions what
      #          is gonna happen to the extended nodes.
      class Runner < Node::Runner
        def call(lib_ctx, flow_options, signal, node, id)
          wrap_runtime = flow_options.fetch(:wrap_runtime)

          lib_ctx, flow_options, signal, node, id = wrap_runtime.(lib_ctx, flow_options, signal, node, id)

          super # DISCUSS: how does super know it has to merge :wrap_runtime?
        end
      end
    end # WrapRuntime
  end
end
