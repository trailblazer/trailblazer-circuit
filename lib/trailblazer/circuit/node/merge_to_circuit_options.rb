module Trailblazer
  class Circuit
    class Node
      class MergeToCircuitOptions < Struct.new(:task, :interface, :options, :merge_to_circuit_options, keyword_init: true) # DISCUSS: better name?
        def self.[](task, interface, options: {}, merge_to_circuit_options: {})
          new(
            task: task,
            interface: interface,
            options: options,
            merge_to_circuit_options: merge_to_circuit_options
          )
        end

        include Trailblazer::Circuit::Node::Call

        def call(lib_ctx, flow_options, signal, circuit_options)
          super(lib_ctx, flow_options, signal, circuit_options.merge(merge_to_circuit_options))
        end
      end
    end
  end
end
