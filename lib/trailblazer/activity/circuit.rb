module Trailblazer
  class Activity
    # Running a Circuit instance will run all tasks sequentially depending on the former's result.
    # Each task is called and retrieves the former task's return values.
    #
    # Note: Please use #Activity as a public circuit builder.
    #
    # @param map         [Hash] Defines the wiring.
    # @param stop_events [Array] Tasks that stop execution of the circuit.
    #
    #   result = circuit.(start_at, *args)
    #
    # @see Activity
    # @api semi-private
    #
    # This is the "pipeline operator"'s implementation.
    class Circuit
      def initialize(map, stop_events, start_task:, name: nil)
        @map         = map
        @stop_events = stop_events
        @name        = name
        @start_task  = start_task
      end

      # @param args [Array] all arguments to be passed to the task's `call`
      # @param task [callable] task to call
      Run = ->(task, args, **circuit_options) { task.(args, **circuit_options) }

      # Runs the circuit until we hit a stop event.
      #
      # This method throws exceptions when the returned value of a task doesn't match
      # any wiring.
      #
      # @param task An event or task of this circuit from where to start
      # @param options anything you want to pass to the first task
      # @param flow_options Library-specific flow control data
      # @return [last_signal, options, flow_options, *args]
      #
      # NOTE: returned circuit_options are discarded when calling the runner.
      def call(args, start_task: @start_task, runner: Run, **circuit_options)
        circuit_options = circuit_options.merge( runner: runner ).freeze # TODO: set the :runner option via arguments_for_call to save the merge?
        task            = start_task

        loop do
          last_signal, args, _discarded_circuit_options = runner.(
            task,
            args,
            **circuit_options
          )

          # Stop execution of the circuit when we hit a stop event (< End). This could be an task's End or Suspend.
          return [ last_signal, args ] if @stop_events.include?(task) # DISCUSS: return circuit_options here?

          if (next_task = next_for(task, last_signal))
            task = next_task
          else
            raise IllegalSignalError.new(
              task,
              signal: last_signal,
              outputs: @map[task],
              exec_context: circuit_options[:exec_context], # passed at run-time from DSL
            )
          end
        end
      end

      # Returns the circuit's components.
      def to_h
        { map: @map, end_events: @stop_events, start_task: @start_task }
      end

      private

      def next_for(last_task, signal)
        outputs = @map[last_task]
        outputs[signal]
      end

      # Common reasons to raise IllegalSignalError are when returning signals from
      #   * macros which are not registered
      #   * subprocesses where parent process have not registered that signal
      #   * ciruit interface steps, for example: `step task: method(:validate)`
      class IllegalSignalError < RuntimeError
        attr_reader :task, :signal

        def initialize(task, signal:, outputs:, exec_context:)
          @task = task
          @signal = signal

          message = "#{exec_context.class}: \n" \
            "\e[31mUnrecognized Signal `#{signal.inspect}` returned from #{task.inspect}. Registered signals are, \e[0m\n" \
            "\e[32m#{outputs.keys.map(&:inspect).join("\n")}\e[0m"

          super(message)
        end
      end
    end
  end
end
