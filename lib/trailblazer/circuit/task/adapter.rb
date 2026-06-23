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
            def self.call(task, ctx, flow_options, signal, exec_context:, **)
              exec_context.send(task, ctx, flow_options, signal, **ctx)
            end
          end
        end

        # The step interface is only used on the application level.
        class StepInterface
          def self.call(provider, lib_ctx, flow_options, signal, **circuit_options)
            result = compute_result(provider, circuit_options, **lib_ctx)

            return lib_ctx, flow_options, result # value-on-signal
          end

          def self.compute_result(provider, circuit_options, target_ctx:, **)
            invoke_provider(provider, target_ctx, **circuit_options)
          end

          def self.invoke_provider(provider, target_ctx, **)
            provider.(target_ctx, **target_ctx.to_h)
          end

          class InstanceMethod < StepInterface
            def self.invoke_provider(provider, target_ctx, exec_context:, **)
              exec_context.send(provider, target_ctx, **target_ctx.to_h)
            end
          end
        end # StepInterface
      end
    end
  end # Circuit
end
