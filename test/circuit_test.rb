require "test_helper"

class CircuitTest < Minitest::Spec
  it "{.build} computes start and terminus" do
    my_exec_context = T.def_tasks(:a, :b, :c, success_signal: nil)

    my_nodes = {
      a: node_a = Trailblazer::Circuit::Node[:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface],
      b: Trailblazer::Circuit::Node[:b, my_exec_context.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],
      c: Trailblazer::Circuit::Node[:c, my_exec_context.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface],
    }

    my_flow_map = {
      a: {nil => :b},
      b: {nil => :c},
      c: {}, # NOTE: we're doing {flow_map.keys.last} to compute the terminus, that's why we want an empty hash here.
    }

    circuit = Trailblazer::Circuit.build(nodes: my_nodes, flow_map: my_flow_map)


    assert_equal circuit.start_tuple, [:a, node_a]
    assert_equal circuit.termini, [:c]

    assert_run circuit, seq: [:a, :b, :c]
  end
end

class CircuitScopeTest < Minitest::Spec
  it "obviously allows scoping its elements" do
    circuit, _ = _A::Circuit::Builder.Circuit(
      [
        [:a, Capture.new(:a), _A::Circuit::Task::Adapter::LibInterface, scoped: true],
        {nil => :b, Left => :c}
      ], # isolated.
      [
        [:b, Capture.new(:b), _A::Circuit::Task::Adapter::LibInterface, merge_to_lib_ctx: {d: 4}, scoped: true, copy_to_outer_ctx: [:d]],
        {nil => :c, Left => :c}
      ],
      [
        [:c, Capture.new(:c), _A::Circuit::Task::Adapter::LibInterface, scoped: true],
        {}
        ], # isolated, but sees {:d}.
      termini: [:c]
    )

    lib_ctx, flow_options = assert_run circuit, terminus: nil, seq: []
    assert_equal flow_options, {
      application_ctx: {:seq=>[]},

      :a=> a = [{}, {:application_ctx=>{:seq=>[]}}, nil, {}],
      :b=> b = [{:d=>4}, {:application_ctx=>{:seq=>[]}, a: a}, nil, {:d=>4}],
      :c=> c = [{:d=>4}, {:application_ctx=>{:seq=>[]}, a: a, b: b}, nil, {:d=>4}],
    }
  end

  it "internally set variables can be exposed to the follower via :copy_to_outer_ctx" do
    circuit, _ = _A::Circuit::Builder.Circuit(
      [
        [:a, Capture.new(:a, pollute: true), _A::Circuit::Task::Adapter::LibInterface, scoped: true, copy_to_outer_ctx: [:pollute]],
        {nil => :b, Left => :b}
      ],
      [
        [:b, Capture.new(:b), _A::Circuit::Task::Adapter::LibInterface, scoped: true, ],  # sees :pollute
      ],
      termini: [:b]
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
