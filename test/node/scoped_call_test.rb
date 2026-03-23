require "test_helper"

# Test calling Scoped.
class NodeScopedCallTest < Minitest::Spec
  let(:capture_task) { Capture.new(:captured, {pollute: 3}) }

  it "scoping defaults to all get in, nothing gets out" do
    my_node = _A::Circuit::Node::Scoped[:a, capture_task, _A::Circuit::Task::Adapter::LibInterface]

    lib_ctx, flow_options, signal = my_node.(
      {a: 1},
      {b: 2},
      Object,
      context_implementation: Trailblazer::Circuit::Context
    )

    assert_equal lib_ctx, {a: 1} # nothing merged into lib_ctx
    assert_equal flow_options, {:b=>2, :captured=>[{a: 1}, {:b=>2}, Object, {a: 1}]}
    assert_equal signal, Object
  end

  it "{:return_outer_signal} overrides local node's signal" do
    my_node = _A::Circuit::Node::Scoped[:a, Capture.new(:captured, {pollute: 3}, Left), _A::Circuit::Task::Adapter::LibInterface,
      return_outer_signal: true
    ]

    lib_ctx, flow_options, signal = my_node.(
      {a: 1},
      {b: 2},
      Object,
      context_implementation: Trailblazer::Circuit::Context
    )

    assert_equal lib_ctx, {a: 1} # nothing merged into lib_ctx
    assert_equal flow_options, {:b=>2, :captured=>[{a: 1}, {:b=>2}, Object, {a: 1}]}
    assert_equal signal, Object
  end

  it "in: [], out: []" do
    my_node = _A::Circuit::Node::Scoped[:a, capture_task, _A::Circuit::Task::Adapter::LibInterface,
      copy_from_outer_ctx: [],
      copy_to_outer_ctx: []
    ]

    lib_ctx, flow_options, signal = my_node.(
      {a: 1},
      {b: 2},
      Object,
      context_implementation: Trailblazer::Circuit::Context
    )

    assert_equal lib_ctx, {a: 1} # nothing merged into lib_ctx
    assert_equal flow_options, {:b=>2, :captured=>[{}, {:b=>2}, Object, {}]}
    assert_equal signal, Object
  end

  it "in: [:a], out: []" do
    my_node = _A::Circuit::Node::Scoped[:a, capture_task, _A::Circuit::Task::Adapter::LibInterface,
      copy_from_outer_ctx: [:a],
      copy_to_outer_ctx: []
    ]

    lib_ctx, flow_options, signal = my_node.(
      {a: 1, y: true},
      {b: 2},
      Object,
      context_implementation: Trailblazer::Circuit::Context
    )

    assert_equal lib_ctx, {a: 1, y: true} # nothing merged into lib_ctx
    assert_equal flow_options, {:b=>2, :captured=>[{a: 1}, {:b=>2}, Object, {a: 1}]} # we can see {:a} inside.
    assert_equal signal, Object
  end

  it "in: [], out: [:c], expose an internally set variable" do
    my_node = _A::Circuit::Node::Scoped[:a, capture_task, _A::Circuit::Task::Adapter::LibInterface,
      copy_from_outer_ctx: [],
      copy_to_outer_ctx: [:pollute]
    ]

    lib_ctx, flow_options, signal = my_node.(
      {a: 1, y: true},
      {b: 2},
      Object,
      context_implementation: Trailblazer::Circuit::Context
    )

    assert_equal lib_ctx, {a: 1, y: true, pollute: 3} # {:pollute} internally merged into lib_ctx
    assert_equal flow_options, {:b=>2, :captured=>[{}, {:b=>2}, Object, {}]} # we cannot see anything inside.
    assert_equal signal, Object
  end

  it "in: [:a], out: [:c]" do
    my_node = _A::Circuit::Node::Scoped[:a, capture_task, _A::Circuit::Task::Adapter::LibInterface,
      copy_from_outer_ctx: [:a],
      copy_to_outer_ctx: [:pollute]
    ]

    lib_ctx, flow_options, signal = my_node.(
      {a: 1, y: true},
      {b: 2},
      Object,
      context_implementation: Trailblazer::Circuit::Context
    )

    assert_equal lib_ctx, {a: 1, y: true, pollute: 3} # {:pollute} internally merged into lib_ctx
    assert_equal flow_options, {:b=>2, :captured=>[{a: 1}, {:b=>2}, Object, {a: 1}]} # we cannot see anything inside.
    assert_equal signal, Object
  end

  it "in: [], out: [], merge_to_lib_ctx: {z: []}" do
    my_node = _A::Circuit::Node::Scoped[:a, capture_task, _A::Circuit::Task::Adapter::LibInterface,
      copy_from_outer_ctx: [],
      copy_to_outer_ctx: [],
      merge_to_lib_ctx: {z: Module}
    ]

    lib_ctx, flow_options, signal = my_node.(
      {a: 1, y: true},
      {b: 2},
      Object,
      context_implementation: Trailblazer::Circuit::Context
    )

    assert_equal lib_ctx, {a: 1, y: true} # original lib_ctx
    assert_equal flow_options, {:b=>2, :captured=>[{z: Module}, {:b=>2}, Object, {z: Module}]} # we cannot see anything inside.
    assert_equal signal, Object
  end

  it "in: [:a], out: [], merge_to_lib_ctx: {z: []}" do
    my_node = _A::Circuit::Node::Scoped[:a, capture_task, _A::Circuit::Task::Adapter::LibInterface,
      copy_from_outer_ctx: [:a],
      copy_to_outer_ctx: [],
      merge_to_lib_ctx: {z: Module}
    ]

    lib_ctx, flow_options, signal = my_node.(
      {a: 1, y: true},
      {b: 2},
      Object,
      context_implementation: Trailblazer::Circuit::Context
    )

    assert_equal lib_ctx, {a: 1, y: true} # original lib_ctx
    assert_equal flow_options, {:b=>2, :captured=>[{a: 1, z: Module}, {:b=>2}, Object, {a: 1, z: Module}]} # we can see :a and :z.
    assert_equal signal, Object
  end

  it "in: [:a], out: [:c], merge_to_lib_ctx: {z: []}" do
    my_node = _A::Circuit::Node::Scoped[:a, capture_task, _A::Circuit::Task::Adapter::LibInterface,
      copy_from_outer_ctx: [:a],
      copy_to_outer_ctx: [:pollute],
      merge_to_lib_ctx: {z: Module}
    ]

    lib_ctx, flow_options, signal = my_node.(
      {a: 1, y: true},
      {b: 2},
      Object,
      context_implementation: Trailblazer::Circuit::Context
    )

    assert_equal lib_ctx, {a: 1, y: true, pollute: 3} # original lib_ctx
    assert_equal flow_options, {:b=>2, :captured=>[{a: 1, z: Module}, {:b=>2}, Object, {a: 1, z: Module}]} # we can see :a and :z.
    assert_equal signal, Object
  end

  it "nested scoping" do
    # Test that a small utility pipes can work on their own lib_ctx.
    # This pipe produces value_from_a, value_from_b, value_from_c
    my_input_user_method = Pipeline(
      [:a, :call, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: capture_a = Capture.new(:a, {value_from_a: 1})}, copy_to_outer_ctx: [:value_from_a]],
      [:b, :call, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: capture_b = Capture.new(:b, {value_from_b: 2})}], # discard value_from_b.
      [:c, :call, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: capture_c = Capture.new(:c, {value_from_c: 3})}, copy_to_outer_ctx: [:value_from_c]],
    )

    my_input_pipe = Pipeline(
      # [:c, Capture.new(:c)],
      [:d, my_input_user_method, Trailblazer::Circuit::Processor, scoped: true, copy_to_outer_ctx: [:value_from_a]],
    )

    lib_ctx, flow_options = assert_run my_input_pipe, seq: []

    assert_equal lib_ctx, {value_from_a: 1}
    # pp flow_options
    assert_equal flow_options, {
      application_ctx: application_ctx = {seq: []},
      :a=> a = [
        {:exec_context=>capture_a},
        {:application_ctx=>application_ctx},
        nil,
        {:exec_context=>capture_a}
      ],
      :b=>
        [{:value_from_a=>1, :exec_context=>capture_b},
         {:application_ctx=>application_ctx, :a=>a},
         nil,
         {:value_from_a=>1, :exec_context=>capture_b}
       ],
       :c=>
        [
          {:value_from_a=>1, :exec_context=>capture_c},
          {:application_ctx=>application_ctx,
            :a=>a,
            :b=>
            [{:value_from_a=>1, :exec_context=>capture_b},
              {:application_ctx=>application_ctx, :a=>a},
              nil,
              {:value_from_a=>1, :exec_context=>capture_b}
            ],
          },
          nil,
          {:value_from_a=>1, :exec_context=>capture_c}
        ]
      }
  end
end


