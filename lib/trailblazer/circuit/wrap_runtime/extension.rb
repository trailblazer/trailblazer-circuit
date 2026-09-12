module Trailblazer
  class Circuit
    module WrapRuntime
      # NOTE: should be the only entry-point to create an extension.
      def self.Extension(adds:) # currently, we only support ADDS instructions. every thing else, you won't need any {Extension}.
        Extension::AddsInstructions.new(adds)
      end

      # Alter a particular node in Processor#call.
      class Extension
        # This extension obviously only works with a <Circuit object.
        class AddsInstructions < Struct.new(:adds_producer)
          # Apply the ADDS instructions to the current task to extend it (eg adding
          # tracing steps).
          def call(id:, node:, **circuit_options)
            adds_instructions = adds_producer.(id: id, **node.to_h) # DISCUSS: move that up to Extension? Do we actually need it outside of here?

            node_attrs = apply(adds_instructions, **node.to_h)

            # DISCUSS: the remaining code here could be part of the generic Extension.
            node = node.class.new(**node_attrs)

            circuit_options.merge(node: node, id: id)
          end

          # Compute the new circuit by applying ADDS, then return
          # the new (extended) attributes hash for the new Node instance.
          def apply(adds_instructions, task:, **node_attrs)
            extended_task = Circuit::Adds.(task, *adds_instructions)

            {**node_attrs, task: extended_task}
          end
        end

        class Set < Struct.new(:extensions)
          def call(**circuit_options)
            extensions.inject(circuit_options) { |_circuit_options, ext| ext.(**_circuit_options) }
          end
        end
      end

    end # WrapRuntime
  end
end
