module Trailblazer
  class Circuit
    module WrapRuntime
      class Extension
        class NodeWrap # DISCUSS: we are wrapping a node ==> NodeWrap? lol
          def self.call(node:, id:, **circuit_options)
            puts "wrapping in extra node #{id.inspect}"

            # DISCUSS: introduce a delegating special wrap Node class, that doesn't need options.
            node = node.class.new(**node.to_h, options: {already_wrapped: true}) # FIXME: test that we use original {node} class.

            node = Trailblazer::Circuit::Node[
              Trailblazer::Circuit::Builder.Circuit( # this circuit can be extended with tracing, etc.
                [:"_wrapped: #{id}", node: node]
              ),
              Trailblazer::Circuit::Processor,
            ]

            {
              **circuit_options,
              node: node,
              id:   "...#{id}"
            }
          end

          # Returns the configured extension_set but only for node that haven't
          # been wrapped, yet.
          class Resolver < Struct.new(:default_extension_set)
            def [](node:, **circuit_options)
              return default_extension_set unless node.options[:already_wrapped]
            end
          end
        end
      end # Extension
    end
  end
end
