 module Trailblazer
  class Circuit
    # Executes a Circuit instance, implementing the code flow logic.
    # A circuit is basically a hash of tasks pointing to their following tasks,
    # keyed by a signal.
    class Processor
      # TODO: this can still be optimized for runtime speed, even though I spent days on it already.
      def self.call(circuit, lib_ctx, flow_options, signal, runner:, start_tuple: circuit.start_tuple, **circuit_options) # FIXME: allow {:start_task}.
        id, node = start_tuple

        loop do
          # puts ">>>Processor #{id.inspect} <<<#{signal.inspect}>>> #{node.class}"
          circuit_options = {
            **circuit_options,
            runner: runner,
            node:   node # NOTE: you can access the current node in a task via the CircuitInterface.
          }

          lib_ctx, flow_options, signal = runner.(node, lib_ctx, flow_options, signal, **circuit_options)

          id, node = circuit.resolve(id, signal) # DISCUSS: pass id and node?

          return lib_ctx, flow_options, signal unless node
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
