module Trailblazer
  class Circuit
    class Node
      class Scoped < Struct.new(:id, :task, :interface, :merge_to_lib_ctx, :copy_from_outer_ctx, :copy_to_outer_ctx, :return_outer_signal)
        # TODO: test defaulting.
        def initialize(id:, task:, interface:, merge_to_lib_ctx: {}, copy_from_outer_ctx: nil, copy_to_outer_ctx: [], return_outer_signal: false)
          super(id, task, interface, merge_to_lib_ctx, copy_from_outer_ctx, copy_to_outer_ctx, return_outer_signal)
        end

        def self.[](id, task, interface, **options)
          new(id: id, task: task, interface: interface, **options)
        end

        include Node::Call

        # raise "do we need local_circuit_options, e.g. for :start_task?"

        def call(outer_ctx, flow_options, outer_signal, context_implementation:, **circuit_options)# FIXME: we need to "cleanse" the circuit_options from any configuration, dangerous. waht if a higher node has a config that is not filtered out by the Node runner?
          ctx = context_implementation.scope(outer_ctx, copy_from_outer_ctx, merge_to_lib_ctx)

          ctx, flow_options, signal = super(ctx, flow_options, outer_signal, **circuit_options, context_implementation: context_implementation)

            # puts "@@@@ after #{id}!@ #{signal.inspect}"
          ctx, signal = unscope(ctx, outer_ctx, signal, outer_signal, context_implementation)
# puts "@@@@@ #{ctx.inspect}"
          return ctx, flow_options, signal
        end

        # @private
        def unscope(lib_ctx, outer_ctx, signal, outer_signal, context_implementation)
          # Per default, we do NOT copy anything to {outer_ctx}.
          # puts "@@#{local_circuit_options}@@@ #{copy_to_outer_ctx.inspect}"
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
