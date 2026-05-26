require "test_helper"

class CircuitTest < Minitest::Spec
  let(:my_exec_context) { T.def_tasks(:a, :b, :c, success_signal: nil) }
  let(:my_nodes) do
    {
      a: node_a = Trailblazer::Circuit::Node[:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface],
      b: Trailblazer::Circuit::Node[:b, my_exec_context.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],
      c: Trailblazer::Circuit::Node[:c, my_exec_context.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface],
    }
  end

  let(:my_flow_map) do
    {
      a: {nil => :b},
      b: {nil => :c},
      c: {nil => nil},
    }
  end

  it "{.build} computes start" do
    circuit = Trailblazer::Circuit.build(nodes: my_nodes, flow_map: my_flow_map)

    assert_equal circuit.start_tuple, [:a, my_nodes[:a]]

    assert_run circuit, seq: [:a, :b, :c]
  end

  it "{#new} allows setting start manually" do
    my_flow_map = {
      a: {nil => :b},
      b: {nil => :c},
      c: {nil => nil}
    }

    circuit = Trailblazer::Circuit.new(
      my_flow_map,
      [:b, my_nodes[:b]],
      my_nodes,
    )

    assert_equal circuit.start_tuple, [:b, my_nodes[:b]]

    assert_run circuit, seq: [:b, :c]
  end

  it "exposes {#start_tuple} used in {Processor} and {#nodes} and {#flow_map}" do
    circuit = Trailblazer::Circuit.new(
      my_flow_map,
      [:b, my_nodes[:b]],
      my_nodes,
    )

    assert_equal circuit.start_tuple, [:b, my_nodes[:b]]
    assert_equal circuit.nodes, my_nodes
    assert_equal circuit.flow_map, my_flow_map
  end

  it "a Circuit doesn't have explicit termini set, if a signal points to {nil}, it terminates" do
    my_flow_map = {
      a: {nil => :b},
      b: {nil => :c, :Left => nil}, # the :Left signal points to nil, meaning it terminates here.
      c: {nil => nil} # signal from  terminus pointing to nil terminates.
    }

    circuit = Trailblazer::Circuit.build(
      flow_map: my_flow_map,
      nodes: my_nodes,
    )

    assert_run circuit, seq: [:a, :b, :c]
    assert_run circuit, seq: [:a, :b], flow_options: {application_ctx: {seq: [], b: :Left}}, terminus: :Left
  end

  it "should raise with IllegalSignalError (# TODO)" do
    my_flow_map = {
      a: {nil => :b}, # we don't know {"unknown signal"} here.
    }

    circuit = Trailblazer::Circuit.build(
      flow_map: my_flow_map,
      nodes: my_nodes,
    )

    exception = assert_raises KeyError do
      assert_run circuit, seq: [:a],
        application_ctx: {a: "unknown signal"}
    end

    assert_equal exception.message, "key not found: \"unknown signal\""
  end
end

class CircuitScopeTest < Minitest::Spec
  it "obviously allows scoping its elements" do
    circuit = _A::Circuit::Builder.Circuit(
      [:a, Capture.new(:a), scoped: true, connections: {nil => :b, Left => :c}], # isolated.
      [:b, Capture.new(:b), merge_to_lib_ctx: {d: 4}, scoped: true, copy_to_outer_ctx: [:d], connections: {nil => :c, Left => :c}],
      [:c, Capture.new(:c), scoped: true, connections: {nil => nil}], # isolated, but sees {:d}.
    )

    lib_ctx, flow_options = assert_run circuit, terminus: nil, seq: []
    assert_equal flow_options, {
      application_ctx: {:seq=>[]},

      :a=> a = [{}, {:application_ctx=>{:seq=>[]}}, nil, {}],
      :b=> b = [{:d=>4}, {:application_ctx=>{:seq=>[]}, a: a}, nil, {:d=>4}],
      :c=> c = [{:d=>4}, {:application_ctx=>{:seq=>[]}, a: a, b: b}, nil, {:d=>4}],
    }
  end

  it "internally set variables can be exposed to the follower via {:copy_to_outer_ctx}" do
    circuit = _A::Circuit::Builder.Circuit(
      [:a, Capture.new(:a, pollute: true), scoped: true, copy_to_outer_ctx: [:pollute], connections: {nil => :b, Left => :b}],
      [:b, Capture.new(:b), scoped: true, connections: {nil => nil}],  # sees :pollute
    )

    lib_ctx, flow_options = assert_run circuit, terminus: nil, seq: []
    assert_equal flow_options, {
      application_ctx: {:seq=>[]},

      :a=> a = [{}, {:application_ctx=>{:seq=>[]}}, nil, {}],
      :b=> b = [{:pollute=>true}, {:application_ctx=>{:seq=>[]}, a: a}, nil, {:pollute=>true}],
    }
  end

  it "allows discarding the internal signal and return the outer signal with {:return_outer_signal}" do

  end
end

class CircuitResolveTest < Minitest::Spec
  it "{Circuit#resolve} returns the next node and the signal" do
    def self.a(lib_ctx, flow_options, signal, **)
      lib_ctx[:seq_in_lib_ctx] << :a
      return lib_ctx, flow_options, signal
    end
    def self.b(lib_ctx, flow_options, signal, **)
      lib_ctx[:seq_in_lib_ctx] << :b
      return lib_ctx, flow_options, signal
    end

    my_nodes = {
      a: Trailblazer::Circuit::Node[:a, method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface],
      b: Trailblazer::Circuit::Node[:b, method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],
    }

    my_flow_map = {a: Resolver::Fixed.new(:b), b: Resolver::Fixed.new(nil)}

    my_circuit = Class.new(Trailblazer::Circuit) do
      def resolve(current_node_id, signal)
        signal += [current_node_id] # the signal emitted by current_node.

        super
      end
    end.build(flow_map:  my_flow_map, nodes: my_nodes)

    lib_ctx, _ = assert_run my_circuit, seq: [], seq_in_lib_ctx: [], signal: [].freeze, terminus: [:a, :b]

    assert_equal lib_ctx, {seq_in_lib_ctx: [:a, :b]}
  end

  module Resolver
    class Fixed < Struct.new(:next_node_id) # TODO: is it faster to use a simple PORO?
      def fetch(_signal)
        next_node_id
      end
    end
  end

  # it's now possible to either use a "hardcore" signal mapping hash, but it IS also possible
  # to route without caring about the signal, etc.
  it "is possible to use a different resolving hash per node" do
    my_flow_map = {
      a: {Right => :b, Left => :failure}, # normal Resolver from a circuit step.
      b: Resolver::Fixed.new(:c), # like {<any> => :next_step}
      c: Resolver::Fixed.new(nil), # terminate, but return the "original" signal.
      failure: {Right => nil}
    }

    my_exec_context = T.def_tasks(:a, :b, :c, :failure, success_signal: Right)

    my_nodes = {
      a: Trailblazer::Circuit::Node[:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      b: Trailblazer::Circuit::Node[:b, :b, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      c: Trailblazer::Circuit::Node[:c, :c, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      failure: Trailblazer::Circuit::Node[:failure, :failure, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
    }

    my_circuit = Trailblazer::Circuit.build(flow_map: my_flow_map, nodes: my_nodes)

    assert_run my_circuit, terminus: Right, seq: [:a, :b, :c], exec_context: my_exec_context
    assert_run my_circuit, terminus: Right, seq: [:a, :failure], exec_context: my_exec_context, flow_options: {application_ctx: {seq: [], a: Left}}

    # With a Reolver::Fixed, a terminating node can return any signal, but still terminates.
    assert_run my_circuit, terminus: :c_says_Right, seq: [:a, :b, :c], exec_context: my_exec_context, flow_options: {application_ctx: {seq: [], c: :c_says_Right}}
  end

  it "what" do
    raise "Pipeline vs Circuit with Fixed"
    raise "old Circuit vs Circuit with resolving that returns signal"
  end
end
