module Trailblazer
  class Circuit
    module WrapRuntime
      class Extension
        class Resolver < Struct.new(:default_extension_set, :conditions, keyword_init: true) # TODO: where to put, Extension namespace???
          def [](**circuit_options)
            # puts "@@@@@ Resolver #{node.inspect}"
            if conditions.collect do |condition|
                !! condition.(**circuit_options)
              end.uniq == [true]

              return default_extension_set
            end
          end
        end


        class NodeWrap
          class Id < Struct.new(:wrapped_id)
          end

          def self.call(node:, id:, **circuit_options)
            # Here, we still see the original :id we're wrapping.
            # puts "wrapping in extra node #{id.inspect}"

            # DISCUSS: introduce a delegating special wrap Node class, that doesn't need options.
            original_node_options = node.to_h
            new_node_options = original_node_options.merge(options: original_node_options[:options].merge(already_wrapped: true))
            node = node.class.new(**new_node_options) # FIXME: test that we use original {node} class.

            id_for_wrap_node = :"task_wrap.call_task"
            # :"_wrapped: #{id}"

            node = Trailblazer::Circuit::Node[
              Trailblazer::Circuit::Builder.Circuit( # this circuit can be extended with tracing, etc.
                [id_for_wrap_node, node: node]
              ),
              Trailblazer::Circuit::Processor,
            ]

            {
              **circuit_options,
              node: node,
              id:   Id.new(id), # DISCUSS: how to encode we're in a virtual node?
              # node_wrap_data: {wrapped_id: wrapped_id}
            }
          end

          # Returns the configured extension_set but only for node that haven't
          # been wrapped, yet.
          class Resolver# < Struct.new(:default_extension_set)
            CONDITION = ->(node:, **) { ! node.options[:already_wrapped] }
          end
        end
      end # Extension
    end
  end
end
