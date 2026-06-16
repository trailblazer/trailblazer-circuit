 module Trailblazer
  class Circuit
    class Task
      module Adapter
        class LibInterface
          def self.call(task, ctx, flow_options, signal, **)
            # puts "@@@@@ #{ctx.inspect}, LIB  #{lib_ctx}"
            task.(ctx, flow_options, signal, **ctx) # DISCUSS: do we want circuit_options?
          end

          class InstanceMethod
            def self.call(task, ctx, flow_options, signal, **)
              exec_context = ctx.fetch(:exec_context)

              exec_context.send(task, ctx, flow_options, signal, **ctx)
            end
          end

          class InstanceMethod_CircuitOptions # FIXME: make canonical
            def self.call(task, ctx, flow_options, signal, **circuit_options)
              exec_context = circuit_options.fetch(:exec_context)

              exec_context.send(task, ctx, flow_options, signal, **ctx)
            end
          end
        end

        # The step interface is only used on the application level.
        class StepInterface
          def self.call(task, lib_ctx, flow_options, signal, **circuit_options)
            target_ctx = lib_ctx.fetch(:target_ctx) # TODO: introduce second kwargs method that calls {#run_step}.

            result = run_step(task, target_ctx, **lib_ctx)

            return lib_ctx, flow_options, result # value-on-signal
          end

          def self.run_step(task, target_ctx, **)
            task.(target_ctx, **target_ctx.to_h)
          end

          class InstanceMethod < StepInterface
            def self.run_step(task, target_ctx, exec_context:, **)
              exec_context.send(task, target_ctx, **target_ctx.to_h)
            end
          end
        end # StepInterface
      end
    end
  end # Circuit
end
