require "test_helper"

class ProcessorTest < Minitest::Spec
  # DISCUSS: we can also "be" an Adapter directly, should we spare this?
  # DISCUSS: this interface could be officially supported in Adapter, but i'm not sure
  # anyone needs it, we'll see.
  class MyCircuitInterface
    def self.call(task, lib_ctx, flow_options, signal, **circuit_options)
      task.(lib_ctx, flow_options, signal, **circuit_options)
    end
  end

  it "we can see {:node} and {:id} in the {circuit_options} and hence, a MyCircuitInterface task, has access to data stored there" do
    my_task_with_circuit_interface = Struct.new(:my_id) do
      def call(lib_ctx, flow_options, signal, node:, id:, **circuit_options) # MyCircuitInterface.
        lib_ctx[:target_ctx][:seq] << [my_id, id, node]

        return lib_ctx, flow_options, signal
      end
    end

    create_circuit = Pipeline(
      [:id_for_model, my_task_with_circuit_interface.new(:model), MyCircuitInterface],
    )

    create_tw = Pipeline(
      [:id_for_input, my_task_with_circuit_interface.new(:input), MyCircuitInterface],
      [:call_task, create_circuit, Trailblazer::Circuit::Processor],
    )

    assert_run create_tw, seq: [
      [:input, :id_for_input, create_tw.nodes[:id_for_input]],
      [:model, :id_for_model, create_circuit.nodes[:id_for_model]],
    ]
  end

  it "we don't pass {:start_tuple} to the child nodes of the current circuit" do
    my_task_with_circuit_interface = Class.new do
      def call(lib_ctx, flow_options, signal, **circuit_options) # MyCircuitInterface.
        lib_ctx[:ary] << circuit_options.keys

        return lib_ctx, flow_options, signal
      end
    end

    my_circuit = Pipeline(
      [1, my_task_with_circuit_interface.new, MyCircuitInterface],
      [2, my_task_with_circuit_interface.new, MyCircuitInterface],
      [3, my_task_with_circuit_interface.new, MyCircuitInterface],
    )

    lib_ctx, _ = assert_run my_circuit, seq: [], ary: [], circuit_options: {start_tuple: [2, my_circuit.nodes[2]]}

    assert_equal lib_ctx[:ary], [
      [:context_implementation, :runner, :node, :id],
      [:context_implementation, :runner, :node, :id]
    ]
  end
end
