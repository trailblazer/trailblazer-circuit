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
    # TODO: maybe we should test internal properties here, to make sure nodes isn't altered etc.
  end

  # FIXME: private test
  it "prepare_insertion" do
    flow_map, _, nodes = model_tw_pipe.to_a

    _, target_id, target_index = Trailblazer::Circuit::Adds.prepare_insertion(:z, :z, flow_map, nodes, nil, index_for_nil: 0)# before: nil
    assert_equal [target_id, target_index], [:a, 0]
    _, target_id, target_index = Trailblazer::Circuit::Adds.prepare_insertion(:z, :z, flow_map, nodes, :a, index_for_nil: 0)# before: :a
    assert_equal [target_id, target_index], [:a, 0]
    _, target_id, target_index = Trailblazer::Circuit::Adds.prepare_insertion(:z, :z, flow_map, nodes, :b, index_for_nil: 0)# before: :b
    assert_equal [target_id, target_index], [:b, 1]

    _, target_id, target_index = Trailblazer::Circuit::Adds.prepare_insertion(:z, :z, flow_map, nodes, nil, index_for_nil: -1, offset: 1)# after: nil
    assert_equal [target_id, target_index], [:c, -1]
    _, target_id, target_index = Trailblazer::Circuit::Adds.prepare_insertion(:z, :z, flow_map, nodes, :c, index_for_nil: -1, offset: 1)# after: :c
    assert_equal [target_id, target_index], [:c, 3]
    _, target_id, target_index = Trailblazer::Circuit::Adds.prepare_insertion(:z, :z, flow_map, nodes, :a, index_for_nil: -1, offset: 1)# after: :a
    assert_equal [target_id, target_index], [:a, 1]
  end

  it "{:before} with empty pipe" do
    my_pipe = Trailblazer::Circuit::Builder.Pipeline()
    pp my_pipe

    my_extended_pipe = Trailblazer::Circuit::Adds.(
      my_pipe,
      [:a, _A::Circuit::Node[:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface], :before]
    )

    assert_run my_extended_pipe, seq: [:a], terminus: Right
  end

  it "{:after} with empty pipe" do
    my_pipe = Trailblazer::Circuit::Builder.Pipeline()
    pp my_pipe

    my_extended_pipe = Trailblazer::Circuit::Adds.(
      my_pipe,
      [:a, _A::Circuit::Node[:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface], :after]
    )

    assert_run my_extended_pipe, seq: [:a], terminus: Right
  end

  it "{before, nil, before, nil} adds to the beginning, the last becomes the first" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [:z, _A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :before],
      [:y, _A::Circuit::Node::Scoped[:y, :y, interface, **node_options], :before],
    )

    assert_run extended_tw_pipe, seq: [:y, :z, :a, :b, :c], terminus: Right
  end

  it "{before, :b}" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [:z, _A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :before, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :z, :b, :c], terminus: Right
  end

  it "{after, :b}" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [:z, _A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :after, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :b, :z, :c], terminus: Right
  end

  it "{after, :b}, {after: :b}" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [:z, _A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :after, :b],
      [:y, _A::Circuit::Node::Scoped[:y, :y, interface, **node_options], :after, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :b, :y, :z, :c], terminus: Right
  end

  it "{after, nil}, {after: nil}" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [:z, _A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :after],
      [:y, _A::Circuit::Node::Scoped[:y, :y, interface, **node_options], :after],
    )

    assert_run extended_tw_pipe, seq: [:a, :b, :c, :z, :y], terminus: Right
  end

  it ":delete, first node" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [:z, _A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :delete, :a],
    )

    assert_run extended_tw_pipe, seq: [:b, :c], terminus: Right
  end

  it ":delete middle" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [:z, _A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :delete, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :c], terminus: Right
  end

  it ":delete, last" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [:z, _A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :delete, :c],
    )

    assert_run extended_tw_pipe, seq: [:a, :b], terminus: Right
  end

  it ":replace first" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [:z, _A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :replace, :a],
    )

    assert_run extended_tw_pipe, seq: [:z, :b, :c], terminus: Right

    assert_equal extended_tw_pipe.to_a[0].keys, [:z, :b, :c] # TODO: do that everywhere!
  end

  it ":replace middle" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [:z, _A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :replace, :b],
    )

    assert_run extended_tw_pipe, seq: [:a, :z, :c], terminus: Right

    assert_equal extended_tw_pipe.to_a[0].keys, [:a, :z, :c] # TODO: do that everywhere!
  end

  it ":replace last" do
    extended_tw_pipe = Trailblazer::Circuit::Adds.(
      model_tw_pipe,
      [:z, _A::Circuit::Node::Scoped[:z, :z, interface, **node_options], :replace, :c],
    )

    assert_run extended_tw_pipe, seq: [:a, :b, :z], terminus: Right

    assert_equal extended_tw_pipe.to_a[0].keys, [:a, :b, :z] # TODO: do that everywhere!
  end

  it "inserting same ID twice raises with {:before}" do
    exception = assert_raises Trailblazer::Circuit::Adds::IllegalIdError do
      extended_tw_pipe = Trailblazer::Circuit::Adds.(model_tw_pipe, [:a, nil, :before])
    end

    assert_equal exception.message, %(ID {:a} already taken.)
  end

  it "inserting same ID twice raises with {:after}" do
    exception = assert_raises Trailblazer::Circuit::Adds::IllegalIdError do
      extended_tw_pipe = Trailblazer::Circuit::Adds.(model_tw_pipe, [:a, nil, :after])
    end

    assert_equal exception.message, %(ID {:a} already taken.)
  end

  # Circuit-relevant
  let(:my_circuit) do
    Trailblazer::Circuit::Builder.Circuit(
      [:a, my_exec_context.method(:a), connections: {Right => :b, Left => :c}],
      [:b, my_exec_context.method(:b), connections: {Right => nil}],
      [:c, my_exec_context.method(:c), connections: {Right => nil}],
    )
  end

  let(:lib_interface) { Trailblazer::Circuit::Task::Adapter::LibInterface }

  it "the {my_circuit} fixture does what we expect it to do" do
    assert_run my_circuit, terminus: Right, seq: [:a, :b]
    assert_run my_circuit, terminus: Right, seq: [:a, :c], flow_options: {application_ctx: {seq: [], a: Left}}
  end

  it "{after, :a, inbound_signal: Left, outbound_signal: Right}" do
    extended_circuit = Trailblazer::Circuit::Adds.(
      my_circuit,
      [:z, _A::Circuit::Node[:z, my_exec_context.method(:z), lib_interface], :after, :a, inbound_signal: Left, outbound: [[Right]]],
    )

    assert_run extended_circuit, seq: [:a, :b], terminus: Right
    assert_run extended_circuit, terminus: Right, seq: [:a, :z, :c], flow_options: {application_ctx: {seq: [], a: Left}}
  end

  it "{before, :c, inbound_signal: Left, outbound_signal: Right}" do
    extended_circuit = Trailblazer::Circuit::Adds.(
      my_circuit,
      [:z, _A::Circuit::Node[:z, my_exec_context.method(:z), lib_interface], :before, :c, inbound_signal: Left, outbound: [[Right]]],
    )

    #  :a --> :c
    #  ||
    #  :b

    #  :a --> :z --> :c
    #  ||
    #  :b

    assert_run extended_circuit, seq: [:a, :b], terminus: Right
    assert_run extended_circuit, terminus: Right, seq: [:a, :z, :c], flow_options: {application_ctx: {seq: [], a: Left}}
  end


  it "we can define {:outbound} instead of using defaults with {:after}" do
    extended_circuit = Trailblazer::Circuit::Adds.(
      my_circuit,
      [:z, _A::Circuit::Node[:z, my_exec_context.method(:z), lib_interface], :after, :a, inbound_signal: Left, outbound: [[Right, nil], [:MySignal]]],
    )

    assert_run extended_circuit, seq: [:a, :b], terminus: Right
    assert_run extended_circuit, terminus: Right, seq: [:a, :z], flow_options: {application_ctx: {seq: [], a: Left}}
    assert_run extended_circuit, terminus: Right, seq: [:a, :z, :c], flow_options: {application_ctx: {seq: [], a: Left, z: :MySignal}}
  end

  it "we can define {:outbound_connections} with {:before}" do
    extended_circuit = Trailblazer::Circuit::Adds.(
      my_circuit,
      [:z, _A::Circuit::Node[:z, my_exec_context.method(:z), lib_interface], :before, :c, inbound_signal: Left, outbound_connections: {Right => nil, :MySignal => :c}],
    )

    assert_run extended_circuit, seq: [:a, :b], terminus: Right
    assert_run extended_circuit, terminus: Right, seq: [:a, :z], flow_options: {application_ctx: {seq: [], a: Left}}
    assert_run extended_circuit, terminus: Right, seq: [:a, :z, :c], flow_options: {application_ctx: {seq: [], a: Left, z: :MySignal}}
  end

  it "we can use {:outbound} with {:before}, it adds the descendent for us" do
    extended_circuit = Trailblazer::Circuit::Adds.(
      my_circuit,
      [:z, _A::Circuit::Node[:z, my_exec_context.method(:z), lib_interface], :before, :c, inbound_signal: Left, outbound: [[Right, nil], [:MySignal]]], # will be resolved to {Right => nil, MySignal => :c}
    )

    assert_run extended_circuit, seq: [:a, :b], terminus: Right
    assert_run extended_circuit, terminus: Right, seq: [:a, :z], flow_options: {application_ctx: {seq: [], a: Left}}
    assert_run extended_circuit, terminus: Right, seq: [:a, :z, :c], flow_options: {application_ctx: {seq: [], a: Left, z: :MySignal}}
  end

  it "with :inbound_signal, the predecessor represents the first node that points to target via {inbound_signal}" do
    my_circuit = Trailblazer::Circuit::Builder.Circuit(
      [:a, my_exec_context.method(:a), connections: {Right => :c, Left => :b}],
      [:b, my_exec_context.method(:b), connections: {Right => :c}],
      [:c, my_exec_context.method(:c), connections: {Right => nil}]# we got two (:a and :b) both pointing to :c.
    )

    my_circuit = Trailblazer::Circuit::Adds.(
      my_circuit,
      [:z, _A::Circuit::Node[:z, my_exec_context.method(:z), lib_interface], :before, :c, inbound_signal: Right, outbound_connections: {Right => :c}],
    )

    # a --> c
    #   --> b --> c

    # a --> z --> c
    #   --> b --> c

    assert_run my_circuit, seq: [:a, :z, :c], terminus: Right
    assert_run my_circuit, terminus: Right, seq: [:a, :b, :c], flow_options: {application_ctx: {seq: [], a: Left}}
  end
end
