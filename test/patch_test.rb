require "test_helper"

class PatchTest < Minitest::Spec
  let(:my_exec_context) { T.def_tasks(:a, :b, :c, :d, :e, success_signal: nil) }

  it "what" do
    my_pipe = Trailblazer::Circuit::Builder.Pipeline(
      [:a, my_exec_context.method(:a)],
      [:b, my_exec_context.method(:b)],
    )

    my_outer_pipe = Trailblazer::Circuit::Builder.Pipeline(
      [:c, my_exec_context.method(:c)],
      [:ab, my_pipe, Trailblazer::Circuit::Processor],
    )

    my_top_pipe = Trailblazer::Circuit::Builder.Pipeline(
      [:d, my_exec_context.method(:d)],
      [:abc, my_outer_pipe, Trailblazer::Circuit::Processor],
    )
    my_top_node = Trailblazer::Circuit::Node[:top, my_top_pipe, Trailblazer::Circuit::Processor]

    # patch on the top pipe itself.
    my_new_top_node = Trailblazer::Circuit::Node::Patch.(
      my_top_node,
      [],
      adds: [
        [
          Trailblazer::Circuit::Node[:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface], # TODO: provide shortcut from Builder.
          :replace, :d
        ]
      ]
    )

    # patch two levels down.
    node_two_levels_patched = Trailblazer::Circuit::Node::Patch.(
      my_top_node,
      [:abc],
      adds: [
        [
          Trailblazer::Circuit::Node[:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface],
          :after, :c
        ]
      ]
    )

    # patch three levels down.
    node_three_levels_patched = Trailblazer::Circuit::Node::Patch.(
      my_top_node,
      [:abc, :ab],
      adds: [
        [
          Trailblazer::Circuit::Node[:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface],
          :after, :a
        ]
      ]
    )

    assert_run my_top_node, node: true, seq: [:d, :c, :a, :b]
    assert_run my_new_top_node, node: true, seq: [:e, :c, :a, :b]
    assert_run node_two_levels_patched, node: true, seq: [:d, :c, :e, :a, :b]
    assert_run node_three_levels_patched, node: true, seq: [:d, :c, :a, :e, :b]
  end
end
