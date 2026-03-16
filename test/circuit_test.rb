require "test_helper"

class CircuitScopeTest < Minitest::Spec
  it "obviously allows scoping its elements" do
    circuit, _ = _A::Circuit::Builder.Circuit(
      [
        [:a, Capture.new(:a), _A::Circuit::Task::Adapter::LibInterface, {}, _A::Circuit::Node::Scoped],
        {nil => :b, Left => :c}
      ], # isolated.
      [
        [:b, Capture.new(:b), _A::Circuit::Task::Adapter::LibInterface, {}, _A::Circuit::Node::Scoped, copy_to_outer_ctx: [:d], merge_to_lib_ctx: {d: 4}],
        {nil => :c, Left => :c}
      ],
      [
        [:c, Capture.new(:c), _A::Circuit::Task::Adapter::LibInterface, {}, _A::Circuit::Node::Scoped],
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
        [:a, Capture.new(:a, pollute: true), _A::Circuit::Task::Adapter::LibInterface, {}, _A::Circuit::Node::Scoped, copy_to_outer_ctx: [:pollute]],
        {nil => :b, Left => :b}
      ],
      [
        [:b, Capture.new(:b), _A::Circuit::Task::Adapter::LibInterface, {}, _A::Circuit::Node::Scoped, ],  # sees :pollute
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
end
