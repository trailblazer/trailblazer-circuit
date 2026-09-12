module Trailblazer
  class Circuit
    class Node
      class Scoped < Struct.new(:task, :interface, :options, :merge_to_lib_ctx, :copy_from_outer_ctx, :copy_to_outer_ctx, :return_outer_signal, keyword_init: true)
        def self.[](task, interface, options: {}, merge_to_lib_ctx: {}, copy_from_outer_ctx: nil, copy_to_outer_ctx: [], return_outer_signal: false)
          new(
            task: task,
            interface: interface,
            options: options,
            merge_to_lib_ctx: merge_to_lib_ctx,
            copy_from_outer_ctx: copy_from_outer_ctx,
            copy_to_outer_ctx: copy_to_outer_ctx,
            return_outer_signal: return_outer_signal
          )
        end

        include Node::Call

        # raise "do we need local_circuit_options, e.g. for :start_task?"

        def call(outer_ctx, flow_options, outer_signal, **circuit_options)
          ctx = scope(outer_ctx, flow_options, outer_signal, **circuit_options)

          ctx, flow_options, signal = super(ctx, flow_options, outer_signal, **circuit_options)

          ctx, signal = unscope(ctx, outer_ctx, signal, outer_signal, **circuit_options)

          return ctx, flow_options, signal
        end

        # @private
        def scope(outer_ctx, flow_options, outer_signal, context_implementation:, **)
          context_implementation.scope(outer_ctx, copy_from_outer_ctx, merge_to_lib_ctx) # {copy_from_outer_ctx} and {merge_to_lib_ctx} are attrs.
        end

        # @private
        def unscope(lib_ctx, outer_ctx, signal, outer_signal, context_implementation:, **)
          # Per default, we do NOT copy anything to {outer_ctx}.
          lib_ctx = context_implementation.unscope(outer_ctx, lib_ctx, copy_to_outer_ctx)

              # discard the returned signal from this circuit.
              if return_outer_signal
                signal = outer_signal
              end

          return lib_ctx, signal
        end
      end
    end
  end # Circuit
end
