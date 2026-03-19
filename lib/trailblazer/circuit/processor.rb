 module Trailblazer
  class Circuit
    # Executes a Circuit instance, implementing the code flow logic.
    # A circuit is basically a hash of tasks pointing to their following tasks,
    # keyed by a signal.
    class Processor
      # TODO: this can still be optimized for runtime speed, even though I spent days on it already.
      def self.call(circuit, ctx, lib_ctx, signal, runner:, start_node: circuit.to_a_FIXME, **circuit_options) # FIXME: allow {:start_task}.
        # puts "@@@@@??? #{circuit.inspect}"
        # id, task, invoker, circuit_options_to_merge = circuit.to_a_FIXME # we absolutely safely know that we want the start_task here.
        # node = circuit.to_a_FIXME # we absolutely safely know that we want the start_task here.
        id, node = start_node

        loop do
          # puts ">>>Processor #{id.inspect} <<<#{signal.inspect}>>> #{node.class}"
          circuit_options = {
            **circuit_options,
            runner: runner,
            node:   node # NOTE: you can access the current node in a task via the CircuitInterface.
          }

          ctx, lib_ctx, signal = runner.(node, ctx, lib_ctx, signal, **circuit_options)

          id, node = circuit.resolve(id, signal) # DISCUSS: pass id and node?

          return ctx, lib_ctx, signal unless node
          # unless ()

            # raise_illegal_signal_error!(task, signal, @map[task], **circuit_options)
          # end
        end
      end
    end
  end # Circuit
end



        # def raise_illegal_signal_error!(task, last_signal, outputs, **circuit_options)
        #   raise IllegalSignalError.new(
        #     task,
        #     **circuit_options,
        #     signal: last_signal,
        #     outputs: @map[task],
        #   )
        # end

        # # Common reasons to raise IllegalSignalError are when returning signals from
        # #   * macros which are not registered
        # #   * subprocesses where parent process have not registered that signal
        # #   * ciruit interface steps, for example: `step task: method(:validate)`
        # class IllegalSignalError < RuntimeError
        #   attr_reader :task, :signal

        #   def initialize(task, signal:, outputs:, exec_context:, **)
        #     @task = task
        #     @signal = signal

        #     message = "#{exec_context.class}:\n" \
        #       "\e[31mUnrecognized signal `#{signal.inspect}` returned from #{task.inspect}. Registered signals are:\e[0m\n" \
        #       "\e[32m#{outputs.keys.map(&:inspect).join("\n")}\e[0m"

        #     super(message)
        #   end
        # end
