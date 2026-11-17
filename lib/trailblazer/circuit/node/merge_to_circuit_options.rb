module Trailblazer
  class Circuit
    class Node
      class MergeToCircuitOptions < Struct.new(:task, :adapter, :options, :merge_to_circuit_options, keyword_init: true) # DISCUSS: better name?
        def self.[](task, adapter, options: {}, merge_to_circuit_options: {})
          new(
            task: task,
            adapter: adapter,
            options: options,
            merge_to_circuit_options: merge_to_circuit_options
          )
        end

        include Trailblazer::Circuit::Node::Call
        include Trailblazer::Circuit::Node::Merge

        def call(lib_ctx, flow_options, signal, **circuit_options)
          super(lib_ctx, flow_options, signal, **circuit_options, **merge_to_circuit_options)
        end
      end
    end
  end
end
