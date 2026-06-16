module Trailblazer
  class Circuit
    class Node
      class MergeToCircuitOptions < Struct.new(:id, :task, :interface, :merge_to_circuit_options) # DISCUSS: better name?
        include Trailblazer::Circuit::Node::Call

        def call(lib_ctx, flow_options, signal, **circuit_options)
          super(lib_ctx, flow_options, signal, **circuit_options, **merge_to_circuit_options)
        end
      end
    end
  end
end
