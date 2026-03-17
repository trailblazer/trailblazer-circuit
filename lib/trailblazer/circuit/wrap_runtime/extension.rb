# This is an optional feature.
module Trailblazer
  class Circuit
    module WrapRuntime
      class Extension
        # Extension for a particular node in Processor#call.
        class Set < Struct.new(:extensions)
          def call(**node_attrs)
            extensions.inject(node_attrs) { |attrs, ext| ext.(**attrs) }
          end
        end

        class AddsInstructions < Struct.new(:adds_instructions) # "taskWrap" extension.
          # Apply the ADDS instructions to the current task to extend it (eg adding
          # tracing steps).
          def call(task:, **node_attrs)
            extended_task = Trailblazer::Circuit::Adds.(task, *adds_instructions)

            return({task: extended_task, **node_attrs})
          end
        end
      end

    end # WrapRuntime
  end
end
