# This is an optional feature.
module Trailblazer
  class Circuit
    module WrapRuntime
      # Extension for a particular node in Processor#call.
      class Extension < Struct.new(:adds_instructions) # "taskWrap" extension.
        def call(task:, **node_attrs)
          # puts "~~~ @@@@@ #{id.inspect} #{args}"/
          # NOTE: here, we create an extended circuit for the "task".
          extended_task = Trailblazer::Activity::Circuit::Adds.(task, *adds_instructions)

          return( {task: extended_task, **node_attrs})
        end
      end
    end # WrapRuntime
  end
end
