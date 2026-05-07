
require "test_helper"

class PipelineBuilderTest < Minitest::Spec
  let(:exec_context_for_d) do
    Class.new do
      def self.d(lib_ctx, flow_options, circuit_options, signal)
        flow_options[:application_ctx][:seq] << :d

        return lib_ctx, flow_options, Right
      end
    end
  end

  it "{scope: true} creates Node::Scoped" do
    my_task = ->(lib_ctx, flow_options, signal, **) do
      flow_options[:application_ctx][:seq] << :my_pollutor

      return lib_ctx.merge(pollute: true), # this will be discarded *if* this node is scoped.
        flow_options, signal
    end

    my_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:my_pollutor, my_task, scoped: true]
    )

    lib_ctx, _ = assert_run my_circuit, terminus: nil, seq: [:my_pollutor]

    assert_equal lib_ctx, {} # no pollution visible if it was scoped.
  end

  it "{node: MyNode} allows passing a node directly without any DSL logic involved" do
    my_node_with_circuit_interface = Class.new do
      def self.call(lib_ctx, flow_options, signal, **circuit_options)
        flow_options[:application_ctx][:seq] << :e

        return lib_ctx, flow_options, signal
      end
    end

    circuit = Trailblazer::Circuit::Builder.Pipeline(
      # {node: Node.new} allows to bypass all defaulting and Node building.
      [:e, node: my_node_with_circuit_interface],
    )

    lib_ctx, _ = assert_run circuit, terminus: nil,
      seq: [:e]

    assert_equal lib_ctx, {}
  end

  it "provides defaulting" do
    my_tasks = T.def_tasks(:b, :c, :d, success_signal: Right)

    c_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:c, my_tasks.method(:c)]
    )

    circuit = Trailblazer::Circuit::Builder.Pipeline(
      # instance method with lib interface.
      [:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: T.def_tasks(:a, success_signal: nil)}],

      # callable with step interface, we don't get defaulting here.
      [:b, my_tasks.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],

      # defaulting for circuit_options for the nested pipe.
      [:c, c_circuit, Trailblazer::Circuit::Processor],

      # default to LibInterface.
      [:d, my_tasks.method(:d)],
    )

    lib_ctx, _ = assert_run circuit, terminus: Right, # last signal is from {:d}.
      seq: [:a, :b, :c, :d],
      exec_context: exec_context_for_d

    assert_equal lib_ctx, {exec_context: exec_context_for_d}
  end

  it "{Builder.Pipeline} and {Builder::Pipeline.call} are identical" do
    tasks = [
      [:a, :a]
    ]

    assert_equal Trailblazer::Circuit::Builder.Pipeline(*tasks), Trailblazer::Circuit::Builder::Pipeline.(*tasks)
  end
end

class CircuitBuilderTest < Minitest::Spec
  it "what" do
    my_tasks = T.def_tasks(:c, :d, :failure, :success, success_signal: Right)

    c_circuit = Trailblazer::Circuit::Builder.Circuit(
      [:c, my_tasks.method(:c), connections: {Right => :d, Left => :failure}],
      [:d, my_tasks.method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {Right => :success, Left => :failure}],
      [:failure, my_tasks.method(:failure), connections: {Right => nil}], # :connections imply terminus.
      [:success, my_tasks.method(:success), connections: {Right => nil}], # :connections imply terminus.
    )

    lib_ctx, flow_options = assert_run c_circuit, terminus: Right, seq: [:c, :d, :success]
    assert_equal lib_ctx, {}

    lib_ctx, flow_options = assert_run c_circuit, terminus: Right, seq: [:c, :failure], application_ctx: {c: Left}
    assert_equal lib_ctx, {}


    lib_ctx, flow_options = assert_run c_circuit, terminus: Right, seq: [:c, :d, :failure], application_ctx: {d: Left}
    assert_equal lib_ctx, {}
  end

  it "{Builder.Circuit} and {Builder::Circuit.call} are identical" do
    tasks = [
      [:a, :a, connections: {nil => nil}]
    ]

    assert_equal Trailblazer::Circuit::Builder.Circuit(*tasks), Trailblazer::Circuit::Builder::Circuit.(*tasks)
  end
end
