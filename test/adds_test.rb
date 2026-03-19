require "test_helper"

class CircuitAddsTest < Minitest::Spec
  let(:my_exec_context) { T.def_tasks(:a, :b, :c, :d, :e, :z, :y, success_signal: Right) }

  let(:model_tw_pipe) do
    Trailblazer::Circuit::Builder.Pipeline(
      [:a, :a, _A::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: my_exec_context}],
      [:b, :b, _A::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: my_exec_context}],
      [:c, :c, _A::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: my_exec_context}],
    )
  end

  let(:interface) { Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod }
  let(:node_options) { {merge_to_lib_ctx: {exec_context: my_exec_context}} }

  after do
    # No mutation on original circuit.
    assert_run model_tw_pipe, seq: [:a, :b, :c], terminus: Right # def_tasks return Right.
    # TODO: maybe we should test internal properties here, to make sure config isn't altered etc.
  end

  # FIXME: private test
  it "prepare_insertion" do
    flow_map, _, _, config = model_tw_pipe.to_a

    _, target_id, target_index = Trailblazer::Circuit::Adds.prepare_insertion([:z, :z], flow_map, config, nil, index_for_nil: 0)# before: nil
    assert_equal [target_id, target_index], [:a, 0]
    _, target_id, target_index = Trailblazer::Circuit::Adds.prepare_insertion([:z, :z], flow_map, config, :a, index_for_nil: 0)# before: :a
    assert_equal [target_id, target_index], [:a, 0]
    _, target_id, target_index = Trailblazer::Circuit::Adds.prepare_insertion([:z, :z], flow_map, config, :b, index_for_nil: 0)# before: :b
    assert_equal [target_id, target_index], [:b, 1]

    _, target_id, target_index = Trailblazer::Circuit::Adds.prepare_insertion([:z, :z], flow_map, config, nil, index_for_nil: -1, offset: 1)# after: nil
    assert_equal [target_id, target_index], [:c, -1]
    _, target_id, target_index = Trailblazer::Circuit::Adds.prepare_insertion([:z, :z], flow_map, config, :c, index_for_nil: -1, offset: 1)# after: :c
    assert_equal [target_id, target_index], [:c, 3]
    _, target_id, target_index = Trailblazer::Circuit::Adds.prepare_insertion([:z, :z], flow_map, config, :a, index_for_nil: -1, offset: 1)# after: :a
    assert_equal [target_id, target_index], [:a, 1]
  end

  it "{before, nil, before, nil} adds to the beginning, the last becomes the first" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :before],
      [_A::Circuit::Node::Scoped[:y, :y, interface, **node_options], :before],
    )

    assert_run extended_tw_pipe, seq: [:y, :z, :a, :b, :c], terminus: Right
  end

  it "{before, :b}" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :before, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :z, :b, :c], terminus: Right
  end

  it "{after, :b}" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :after, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :b, :z, :c], terminus: Right
  end

  it "{after, :b}, {after: :b}" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :after, :b],
      [_A::Circuit::Node::Scoped[:y, :y, interface, **node_options], :after, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :b, :y, :z, :c], terminus: Right
  end

  it "{after, nil}, {after: nil}" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :after],
      [_A::Circuit::Node::Scoped[:y, :y, interface, **node_options], :after],
    )

    assert_run extended_tw_pipe, seq: [:a, :b, :c, :z, :y], terminus: Right
  end

  it ":delete, first node" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :delete, :a],
    )

    assert_run extended_tw_pipe, seq: [:b, :c], terminus: Right
  end

  it ":delete middle" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :delete, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :c], terminus: Right
  end

  it ":delete, last" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :delete, :c],
    )

    assert_run extended_tw_pipe, seq: [:a, :b], terminus: Right
  end

  it ":replace first" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :replace, :a],
    )

    assert_run extended_tw_pipe, seq: [:z, :b, :c], terminus: Right

    assert_equal extended_tw_pipe.to_a[0].keys, [:z, :b, :c] # TODO: do that everywhere!
  end

  it ":replace middle" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :replace, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :z, :c], terminus: Right

    assert_equal extended_tw_pipe.to_a[0].keys, [:a, :z, :c] # TODO: do that everywhere!
  end

  it ":replace last" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [_A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :replace, :c],
    )

    assert_run extended_tw_pipe, seq: [:a, :b, :z], terminus: Right

    assert_equal extended_tw_pipe.to_a[0].keys, [:a, :b, :z] # TODO: do that everywhere!
  end

  it "can extend Circuit, too" do
    skip

  end
end
