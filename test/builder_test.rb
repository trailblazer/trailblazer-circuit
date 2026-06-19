
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

  def my_pollutor(lib_ctx, flow_options, signal, pollute:, **)
    flow_options[:application_ctx][:seq] << pollute

    return lib_ctx.merge(pollute => true), # this will be discarded *if* this node is scoped.
      flow_options, signal
  end

  it "{scope: true} creates Node::Scoped" do
    my_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:my_pollutor, method(:my_pollutor), scoped: true]
    )

    lib_ctx, _ = assert_run my_circuit, terminus: nil, seq: [1], pollute: 1

    assert_equal lib_ctx, {pollute: 1} # only the original lib_ctx is here.
  end

  it "{scope: true} with {:connections}" do
    my_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:my_pollutor, method(:my_pollutor), scoped: true, connections: {Right => [nil, Right], Left => [:b, "my left"]}]
    )

    lib_ctx, _ = assert_run my_circuit, terminus: Right, seq: [1], pollute: 1, signal: Right
    assert_equal lib_ctx, {pollute: 1} # only the original lib_ctx is here.
    lib_ctx, _ = assert_run my_circuit, terminus: "my left", seq: [1], pollute: 1, signal: Left
    assert_equal lib_ctx, {pollute: 1} # only the original lib_ctx is here.
  end

  it "Pipeline creates a Scoped node when {:merge_to_lib_ctx} is given" do
    my_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:ying, method(:my_pollutor), Trailblazer::Circuit::Task::Adapter::LibInterface, merge_to_lib_ctx: {pollute: 1}],
      [:yang, method(:my_pollutor), Trailblazer::Circuit::Task::Adapter::LibInterface, merge_to_lib_ctx: {pollute: 2}],
    )

    lib_ctx, _ = assert_run my_circuit, terminus: nil, seq: [1, 2]

    assert_equal lib_ctx, {} # no pollution as we're Scoped.
  end

  it "creates a {MergeToCircuitOptions} node when {:exec_context} is given" do
    my_exec_context = T.def_tasks(:a, :b, success_signal: Right)

    my_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, exec_context: my_exec_context],
      [:b, :b, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, exec_context: my_exec_context],
    )

    lib_ctx, _ = assert_run my_circuit, terminus: Right, seq: [:a, :b]

    assert_equal lib_ctx, {}
  end

  it "Pipeline creates an unscoped Node when no options given" do
    my_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:my_pollutor, method(:my_pollutor)]
    )

    lib_ctx, _ = assert_run my_circuit, terminus: nil, seq: [1], pollute: 1

    assert_equal lib_ctx, {pollute: 1, 1 => true}
  end

  it "{node: MyNode} allows passing a node directly without any DSL logic involved" do
    my_node_with_circuit_interface = Class.new do
      def self.call(lib_ctx, flow_options, signal, circuit_options)
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

  it "TODO: :connections should be :resolver" do

  end

  it "provides defaulting" do
    my_tasks = T.def_tasks(:b, :c, :d, success_signal: Right)

    c_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:c, my_tasks.method(:c)]
    )

    circuit = Trailblazer::Circuit::Builder.Pipeline(
      # instance method with lib interface.
      [:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, exec_context: T.def_tasks(:a, success_signal: nil)],

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

  it "when omitting {:connections} it builds a Pipeline node (with a Fixed resolver to next element)" do
    my_exec_context = T.def_tasks(:a, :b, :c, success_signal: Right)
    my_exec_context_2 = T.def_tasks(:d, success_signal: Right)

    # defaulting for {:connections}.
    my_circuit = Trailblazer::Circuit::Builder.Pipeline(
      # We're omitting {:connections} but provide additional options.
      [:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, exec_context: my_exec_context],

      # defaulting for {:connections} and {interface}.
      [:b, my_exec_context.method(:b)],

      # provide the interface.
      [:c, :c, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],

      # provide the interface and additional options.
      [:d, :d, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod,
        exec_context: my_exec_context_2,
        connections: {Left => [nil, Left]}
      ],
    )

    lib_ctx, flow_options = assert_run my_circuit, terminus: Left, seq: [:a, :b, :c, :d],
      circuit_options: {exec_context: my_exec_context},
      flow_options: {application_ctx: {seq: [], d: Left}}

    assert_equal lib_ctx, {}
  end

  it "we can pass resolvers as {:connections}" do
    my_exec_context = T.def_tasks(:a, :b, :c, success_signal: Right)

    my_circuit = Trailblazer::Circuit::Builder.Circuit(
      # hash resolver.
      [:a, my_exec_context.method(:a), connections: {Right => [:b, Right], Left => [nil, Left]}],
      [:b, my_exec_context.method(:b), connections: Trailblazer::Circuit::Resolver::Fixed.new(:c)],
      # a Fixed resolver, used in pipelines.
      [:c, my_exec_context.method(:c), connections: Trailblazer::Circuit::Resolver::Fixed.new(nil)],
    )

    assert_run my_circuit, terminus: Left, seq: [:a], application_ctx: {a: Left}
    assert_run my_circuit, terminus: Right, seq: [:a, :b, :c]#, application_ctx: {a: Left}
    # test that the Fixed resolver does its job.
    assert_run my_circuit, terminus: Right, seq: [:a, :b, :c], application_ctx: {b: Object}
  end

  it "{Builder.Pipeline} and {Builder::Pipeline.call} are identical" do
    tasks = [
      [:a, :a]
    ]

    assert_equal Trailblazer::Circuit::Builder.Pipeline(*tasks), Trailblazer::Circuit::Builder::Pipeline.(*tasks, pipe_FIXME: true)
  end
end

class CircuitBuilderTest < Minitest::Spec
  it "what" do
    my_tasks = T.def_tasks(:c, :d, :failure, :success, success_signal: Right)

    my_circuit = Trailblazer::Circuit::Builder.Circuit(
      [:c, my_tasks.method(:c), connections: {Right => [:d, Right], Left => [:failure, Left]}],
      [:d, my_tasks.method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {Right => [:success, Right], Left => [:failure, Left]}],
      [:failure, my_tasks.method(:failure), connections: {Right => [nil, Right]}], # :connections imply terminus.
      [:success, my_tasks.method(:success), connections: {Right => [nil, Right]}], # :connections imply terminus.
    )

    lib_ctx, flow_options = assert_run my_circuit, terminus: Right, seq: [:c, :d, :success]
    assert_equal lib_ctx, {}

    lib_ctx, flow_options = assert_run my_circuit, terminus: Right, seq: [:c, :failure], application_ctx: {c: Left}
    assert_equal lib_ctx, {}


    lib_ctx, flow_options = assert_run my_circuit, terminus: Right, seq: [:c, :d, :failure], application_ctx: {d: Left}
    assert_equal lib_ctx, {}
  end

  it "{Builder.Circuit} and {Builder::Pipeline.call} are identical" do
    tasks = [
      [:a, :a, connections: {nil => nil}]
    ]

    assert_equal Trailblazer::Circuit::Builder.Circuit(*tasks), Trailblazer::Circuit::Builder::Pipeline.(*tasks, pipe_FIXME: true)
  end
end
