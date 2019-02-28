module Trailblazer
  class Activity
    # Provides DSL and compilation for a {Schema::Implementation}
    # maintaining the actual tasks for a {Schema::Intermediate}.
    #
    # Exposes {Activity::Interface} so this can be used directly in other
    # workflows.
    #
    # NOTE: Work in progress!
    class Implementation
      def self.implement(intermediate, user_options)

        wiring = intermediate.wiring

        outputs_defaults = { # TODO: make this injectable and allow passing more.
          success: Activity::Output(Activity::Right, :success),
          failure: Activity::Output(Activity::Left,  :failure),
        }

        # automatically create {End}s.
        defaults = intermediate.stop_task_refs
        ends_outputs = defaults.collect { |ref| wiring.find { |_ref, connections| _ref.id == ref.id } } # FIXME
        defaults = ends_outputs.collect { |ref, (output, _)|
          {
            id:         ref.id,
            outputs:    {output.semantic => Activity::Output(end_task = Activity::End(output.semantic), output.semantic)},
            task:       end_task,
            extensions: [],
          }
        }

        step_interface_builder = TaskBuilder.method(:Binary) # FIXME

        implementation = wiring.collect do |ref, connections|
          id  = ref.id
          cfg = user_options[id] #or raise "No task passed for #{id.inspect}"

          task_options =
            # macro
            if cfg.is_a?(Hash)
              cfg.merge(id: id)
            # task, **options
            elsif cfg
              task = step_interface_builder.(cfg)
              {id: id, task: task, outputs: outputs_defaults, extensions: []}
            # Start, End, etc.
            else
              defaults.find { |row| row[:id] == id }
            end

          id, task, outputs, extensions = outputs_for_task(wiring, task_options)

          [id, Schema::Implementation::Task(task, outputs, extensions)]
        end

        implementation = Hash[implementation]

        # pp implementation

        schema = Schema::Intermediate.(intermediate, implementation)

        @activity = Activity.new(schema)
      end

      def self.outputs_for_task(wiring, task:, id:, outputs:, extensions:)
        connections = find_outputs_from_intermediate(wiring, id)

        outputs = connections.collect { |connection|
          output   = outputs[connection.semantic]
        }

        return id, task, outputs, extensions
      end

      def self.find_outputs_from_intermediate(wiring, id)
        ref, connections = wiring.find { |ref, connections| ref.id == id }
        connections
      end

=begin
    implementation = {
      :a => Schema::Implementation::Task(implementing.method(:a), [Activity::Output(Right,       :success), Activity::Output(Left, :failure)]),
      :b => Schema::Implementation::Task(implementing.method(:b), [Activity::Output("B/success", :success), Activity::Output("B/failure", :failure)]),
      :c => Schema::Implementation::Task(implementing.method(:c), [Activity::Output(Right,       :success), Activity::Output(Left, :failure)]),
      :d => Schema::Implementation::Task(implementing.method(:d), [Activity::Output("D/success", :success), Activity::Output(Left, :failure)]),
      "End.success" => Schema::Implementation::Task(implementing::Success, [Activity::Output(implementing::Success, :success)]), # DISCUSS: End has one Output, signal is itself?
      "End.failure" => Schema::Implementation::Task(implementing::Failure, [Activity::Output(implementing::Failure, :failure)]),
    }
=end


      def self.call(*args) # FIXME: shouldn't this be coming from Activity::Interface?
        @activity.(*args)
      end
      def self.to_h
        @activity.to_h
      end
      def self.[](*key)
        to_h[:config][*key]
      end
    end

  end
end
