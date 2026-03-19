require "test_helper"

class ProcessorTest < Minitest::Spec
  # DISCUSS: we can also "be" an Adapter directly, should we spare this?
  # DISCUSS: this interface could be officially supported in Adapter, but i'm not sure
  # anyone needs it, we'll see.
  class CircuitInterface
    def self.call(task, lib_ctx, flow_options, signal, **circuit_options)
      task.(lib_ctx, flow_options, signal, **circuit_options)
    end
  end

  it "we can see {:node} in the {circuit_options} and hence, a CircuitInterface task, has access to data stored there" do
    my_task_with_circuit_interface = Struct.new(:my_id) do
      def call(lib_ctx, flow_options, signal, node:, **circuit_options) # CircuitInterface.
        flow_options[:application_ctx][:seq] << [my_id, node]

        return lib_ctx, flow_options, signal
      end
    end

    create_circuit = Pipeline(
      [:model, my_task_with_circuit_interface.new(:model), CircuitInterface],
    )

    create_tw = Pipeline(
      [:input, my_task_with_circuit_interface.new(:input), CircuitInterface],
      [:call_task, create_circuit, Trailblazer::Circuit::Processor],
    )

    canonical_node = Trailblazer::Circuit::Node[:Create, create_tw, Trailblazer::Circuit::Processor]

    assert_run canonical_node, node: true, seq: [
      [:input, create_tw.nodes[:input]],
      [:model, create_circuit.nodes[:model]],
    ]
  end
end
