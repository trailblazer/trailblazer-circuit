require "test_helper"

class NodeBuilderTest < Minitest::Spec
  # Builder.Node
  #
  it "what" do

  end
end

class PipelineBuilderTest < Minitest::Spec
  let(:exec_context_for_d) do
    Class.new do
      def self.d(lib_ctx, flow_options, circuit_options, signal)
        flow_options[:application_ctx][:seq] << :d

        return lib_ctx, flow_options, Right
      end
    end
  end

  let(:exec_context_for_a) do
    T.def_steps(:a)
  end

  it "scope: true" do
    raise
  end

  it "provides defaulting" do
    my_steps = T.def_steps(:b, :c)
    my_tasks = T.def_tasks(:d, success_signal: Right)

    my_node_with_circuit_interface = Class.new do
      def self.call(lib_ctx, flow_options, signal, **circuit_options)
        flow_options[:application_ctx][:seq] << :e

        return lib_ctx, flow_options, signal
      end
    end

    c_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:c, my_steps.method(:c), Trailblazer::Circuit::Task::Adapter::StepInterface]
    )

    circuit = Trailblazer::Circuit::Builder.Pipeline(
      # instance method with step interface.
      [:a, :a, Trailblazer::Circuit::Task::Adapter::StepInterface::InstanceMethod, {exec_context: exec_context_for_a}],

      # callable with step interface, we don't get defaulting here.
      [:b, my_steps.method(:b), Trailblazer::Circuit::Task::Adapter::StepInterface],

      # defaulting for circuit_options for the nested pipe.
      [:c, c_circuit, Trailblazer::Circuit::Processor],

      # task interface with defaulting, lib task with signal # FIXME.
      [:d, :d],

      # {node: Node.new} allows to bypass all defaulting and Node building.
      [:e, node: my_node_with_circuit_interface],
    )

    lib_ctx, _ = assert_run circuit, terminus: Right, # last signal is from {:d}.
      seq: [:a, :b, :c, :d, :e],
      exec_context: exec_context_for_d

    assert_equal lib_ctx, {exec_context: exec_context_for_d, :value=>true}
  end

  it "accepts options for the Node itself" do
    raise
  end

  # it "accepts kwargs as circuit_options defaults" do
  #   circuit = Trailblazer::Circuit::Builder.Pipeline(

  #     # we can manually override the {circuit_options}:
  #     [:a, :a, Trailblazer::Circuit::Task::Adapter::StepInterface::InstanceMethod, {exec_context: exec_context_for_a}],

  #     # or use the pipe-wide default, see two lines below.
  #     [:d, :d],
  #     exec_context: exec_context_for_d
  #   )

  #   assert_run circuit, seq: [:a, :d], terminus: Right # signal from {:a}.
  # end
end

class CircuitBuilderTest < Minitest::Spec
  it "what" do
    my_tasks = T.def_tasks(:c, :d, :success, :failure, success_signal: Right)



    c_circuit, termini = Trailblazer::Circuit::Builder.Circuit(
      [[:c, my_tasks.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface], {Right => :d, Left => :failure}],
      [[:d, my_tasks.method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface], {Right => :success, Left => :failure}],
      [[:failure, failure = my_tasks.method(:failure), _A::Circuit::Task::Adapter::LibInterface]],
      [[:success, success = my_tasks.method(:success), _A::Circuit::Task::Adapter::LibInterface]],

      termini: [:failure, :success],
    )

    success_node = c_circuit.config[:success]
    failure_node = c_circuit.config[:failure]

    assert_equal termini, {success: success_node, failure: failure_node}

    lib_ctx, flow_options = assert_run c_circuit, terminus: Right, seq: [:c, :d, :success]
    assert_equal lib_ctx, {}

    lib_ctx, flow_options = assert_run c_circuit, terminus: Right, seq: [:c, :failure], c: Left
    assert_equal lib_ctx, {}


    lib_ctx, flow_options = assert_run c_circuit, terminus: Right, seq: [:c, :d, :failure], d: Left
    assert_equal lib_ctx, {}
  end
end
