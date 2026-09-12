module Trailblazer
  class Circuit
    # Helpers for those who don't like or have a DSL :D
    module Builder
      # Pipeline is just another circiut, where each step has only one output.
      def self.Pipeline(*args)
        Builder::Pipeline.(*args)
      end

      def self.Circuit(*args)
        Builder::Pipeline.(*args)
      end

      module Pipeline
        module_function

        def call(*rows_from_user)
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
          )
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
            options_for_node = {merge_to_circuit_options: {exec_context: exec_context}, **options_for_node}
          end

          return id, node_class[task, interface, **options_for_node]
        end
      end
    end # Builder
  end
end
