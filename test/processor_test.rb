require "test_helper"

class ProcessorTest < Minitest::Spec
  it "we can see :node in circuit_options" do
    skip
    my_exec_context = Struct.new(:my_id) do
      def call(lib_ctx, flow_options, signal, node:, **circuit_options) # CircuitInterface.
        puts "@@@@@ #{my_id} #{node.id.inspect}"

        return lib_ctx, flow_options, signal
      end
    end

    create_circuit = Pipeline(
      [:model, my_exec_context.new(:model), Trailblazer::Circuit::Task::Adapter::CircuitInterface],
    )

    create_tw = Pipeline(
      [:input, my_exec_context.new(:input), Trailblazer::Circuit::Task::Adapter::CircuitInterface],
      [:call_task, create_circuit, Trailblazer::Circuit::Processor],
    )

    canonical_node = Trailblazer::Circuit::Node[id: :Create, task: create_tw, interface: Trailblazer::Circuit::Processor]

    lib_ctx, flow_options, signal = Trailblazer::Circuit::Node::Runner.(
      canonical_node,
      {},
      {
        #application_ctx: {params: {id: 1, title: "Rancid"}},
      },
      nil,
      runner: Trailblazer::Circuit::Node::Runner,
      context_implementation: Trailblazer::Circuit::Context,
    )

    assert_equal signal, nil
  end
end
