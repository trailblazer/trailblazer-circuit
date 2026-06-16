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

  it "we can see {:node} in the {circuit_options} and hence, a MyCircuitInterface task, has access to data stored there" do
    my_task_with_circuit_interface = Struct.new(:my_id) do
      def call(lib_ctx, flow_options, signal, node:, **circuit_options) # MyCircuitInterface.
        flow_options[:application_ctx][:seq] << [my_id, node]

        return lib_ctx, flow_options, signal
      end
    end

    create_circuit = Pipeline(
      [:model, my_task_with_circuit_interface.new(:model), MyCircuitInterface],
    )

    create_tw = Pipeline(
      [:input, my_task_with_circuit_interface.new(:input), MyCircuitInterface],
      [:call_task, create_circuit, Trailblazer::Circuit::Processor],
    )

    assert_run create_tw, seq: [
      [:input, create_tw.nodes[:input]],
      [:model, create_circuit.nodes[:model]],
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
      [:context_implementation, :runner, :node],
      [:context_implementation, :runner, :node]
    ]
  end
end
