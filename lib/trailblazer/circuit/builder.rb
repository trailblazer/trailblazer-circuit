module Trailblazer
  class Circuit
    # Helpers for those who don't like or have a DSL :D
    module Builder
      # Pipeline is just another circiut, where each step has only one output.
      def self.Pipeline(*task_cfgs, **default_circuit_options)
        raise if default_circuit_options.any?

        config = Pipeline.build_node_from_dsl(task_cfgs)

        map = task_cfgs.collect.with_index do |(id, _), i|
          next_task = task_cfgs[i + 1]
          signal = nil

          [
            id,
            {signal => next_task ? next_task[0] : nil} # FIXME: don't link last task at all!
          ]
        end.to_h

        Circuit::Pipeline.build(
          flow_map: map,
          config:   config,
        )
      end

      module Pipeline
        module_function

        # Produces a set of {Node}s, currently called "config".
        def build_node_from_dsl(task_cfgs)
          # Disect the incoming DSL bogus into input for #build_node_from_dsl.
          task_cfgs.collect do |id, task, *args|
            node =
              if task.is_a?(Hash)
                task.fetch(:node)
              else
                args, options_for_node = args
                options_for_node ||= {}

                # Handle the [id, task, scoped: true] case, which is perfectly legal.
                if options_for_node.empty? && args.is_a?(Hash)
                  args, options_for_node = [], args
                end

                create_node(id, task, *args, **options_for_node)
              end

            [id, node]
          end.to_h
        end

        # Defaulting happens here.
        def create_node(id, task, interface = Task::Adapter::LibInterface::InstanceMethod, scoped: false, merge_to_lib_ctx: nil, **options_for_node)
          node_class = Node
          node_class = Node::Scoped if scoped || merge_to_lib_ctx
          options_for_node = options_for_node.merge(merge_to_lib_ctx: merge_to_lib_ctx) if merge_to_lib_ctx

          node_class[id, task, interface, **options_for_node]
        end
      end

      def self.Circuit(*task_rows, termini:)
        task_cfgs         = task_rows.collect { |(task_cfg, connections)| task_cfg }
        id_to_connections = task_rows.collect { |(task_cfg, connections)| [task_cfg[0], connections] }.to_h

        config = Pipeline.build_node_from_dsl(task_cfgs)

        outputs = termini.collect do |semantic|
          terminus_task = config[semantic]

          [semantic, terminus_task]
        end.to_h

        map = config.collect do |id, node|
          connections = id_to_connections[id]

          [id, connections]
        end.to_h

        return Circuit.new(
            map:            map,
            start_task_id:  config.keys[0],
            termini:        termini,
            config:         config,
          ),
          outputs
      end

      # FIXME: MOVE TO Activity?
      # A taskWrap is just a Pipeline with a mandatory element {call_task}.
      # @private
      def self.TaskWrap(*nodes_options)
        raise "no call_task provided!" unless nodes_options.find { |(id, _)| id == :"task_wrap.call_task" }

        Pipeline(*nodes_options)
      end

      # DISCUSS: should that sit in Activity? it's higher level than Circuit.
      # TODO: test me.
      # DISCUSS: this is a "std-lib" component. move this to {activity}.
      module Step
        def self.InstanceMethod(method_name)
          Builder.Pipeline(
            [:invoke_instance_method, method_name, Task::Adapter::StepInterface::InstanceMethod], # FIXME: we're currenly assuming that exec_context is passed down.
            [:compute_binary_signal, Activity::Step::ComputeBinarySignal, Task::Adapter::LibInterface],
          )
        end

        def self.Callable(callable)
          Builder.Pipeline(
            [:invoke_callable, callable, Trailblazer::Activity::Circuit::Task::Adapter::StepInterface],
            [:compute_binary_signal, Activity::Step::ComputeBinarySignal, Trailblazer::Activity::Circuit::Task::Adapter::LibInterface],
          )
        end
      end
    end # Builder
  end
end
