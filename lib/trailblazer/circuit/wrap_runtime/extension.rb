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
          def call(task:, **node_attrs)
             adds_instructions = adds_producer.(task: task, **node_attrs) # DISCUSS: move that up to Extension? Do we actually need it outside of here?

            extended_task = Circuit::Adds.(task, *adds_instructions)

            {task: extended_task, **node_attrs}
          end
        end

        class Set < Struct.new(:extensions)
          def call(**node_attrs)
            extensions.inject(node_attrs) { |attrs, ext| ext.(**attrs) }
          end
        end
      end

    end # WrapRuntime
  end
end
