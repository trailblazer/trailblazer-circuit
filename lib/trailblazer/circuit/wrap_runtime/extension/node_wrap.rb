module Trailblazer
  class Circuit
    module WrapRuntime
      class Extension
        class NodeWrap # TODO: rename to WrapNode, cause that's what it is!!!
          class Id < Struct.new(:wrapped_id, :wrapped_node)
            def to_sym # FIXME: test me
              wrapped_id
            end
          end

          def self.call(*args, node:, id:, **circuit_options)
            # Here, we still see the original :id we're wrapping.
            # puts "wrapping in extra node #{id.inspect}"

            wrapped_node = node
            # DISCUSS: introduce a delegating special wrap Node class, that doesn't need options.
            original_node_options = node.to_h
            new_node_options = original_node_options.merge(options: original_node_options[:options].merge(already_wrapped: true))
            node = node.class.new(**new_node_options) # FIXME: test that we use original {node} class.

            id_for_wrap_node = :"task_wrap.call_task" # FIXME: do we need to invent that? can't we use the original id?

            wrap_node = Trailblazer::Circuit::Node[
              Trailblazer::Circuit::Builder.Circuit( # this circuit can be extended with tracing, etc.
                [id_for_wrap_node, node: node]
              ),
              Trailblazer::Circuit::Processor,
              options: {wrap_node: true}
            ]

            circuit_options = {
              **circuit_options,
              node: wrap_node,
              id:   Id.new(id, wrapped_node), # DISCUSS: how to encode we're in a virtual node?
              # node_wrap_data: {wrapped_id: wrapped_id}
            }

            return *args, circuit_options
          end

          CONDITION = ->(*, node:, **) { ! node.options[:already_wrapped] }
          EXTENSION = WrapRuntime::Extension.new(CONDITION, NodeWrap)
          USER_CONDITION = ->(*, node:, **) { node.options[:wrap_node] } # use this if you want to live the dream in a WrapNode.
        end
      end # Extension
    end
  end
end
