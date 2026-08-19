module Trailblazer
  class Circuit
    # Helpers for those who don't like or have a DSL :D
    module Builder
      # Pipeline is just another circiut, where each step has only one output.
      def self.Pipeline(*args)
        Builder::Pipeline.(*args, pipe_FIXME: true)
      end

      def self.Circuit(*args)
        Builder::Pipeline.(*args, pipe_FIXME: false)
      end

      module Pipeline
        module_function

        def call(*rows_from_user, pipe_FIXME:)
          matrix = rows_from_user.collect.with_index do |(*args, options), i|
            next_task_id, next_task = rows_from_user[i + 1]

            args, options = [*args, options], {} unless options.is_a?(Hash)

            resolver, options = normalize_resolver(next_task_id, **options)

            id, node = build_node_for(*args, **options)

            [
              [id, node],
              [id, resolver]
            ]
          end

          nodes, flow_map = matrix.transpose # fancy!

          Trailblazer::Circuit.build(
            flow_map: flow_map.to_h,
            nodes:    nodes.to_h,
          ).tap do |pipe|
            pipe.instance_variable_set(:@pipe, pipe_FIXME) # FIXME: WE MARK THE CIRCUIT AS A PIPE FOR TW TRACING
          end
        end

        def build_node_for(id, *args, node: nil, **options)
          return id, node if node

          create_node(id, *args, **options)
        end

        def normalize_resolver(next_task_id, connections: Resolver::Fixed.new(next_task_id), **options)
          return connections, options
        end

        # Defaulting happens here.
        def create_node(id, task, interface = Task::Adapter::LibInterface, scoped: false, merge_to_lib_ctx: nil, exec_context: false, **options_for_node)
          node_class = Node

          node_class = Node::Scoped if scoped || merge_to_lib_ctx
          options_for_node = options_for_node.merge(merge_to_lib_ctx: merge_to_lib_ctx) if merge_to_lib_ctx

          if exec_context
            node_class = Node::MergeToCircuitOptions
            options_for_node = {exec_context: exec_context, **options_for_node}
          end

          return id, node_class[task, interface, **options_for_node]
        end
      end

      # FIXME: MOVE TO Activity?
      # A taskWrap is just a Pipeline with a mandatory element {call_task}.
      # @private
      def self.TaskWrap(*nodes_options)
        raise "no call_task provided!" unless nodes_options.find { |(id, _)| id == :"task_wrap.call_task" }

        Pipeline(*nodes_options)
      end
    end # Builder
  end
end
