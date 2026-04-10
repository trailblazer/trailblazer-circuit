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

    # patch on the top pipe itself.
    my_new_top_pipe = Trailblazer::Circuit::Patch.(
      my_top_pipe,
      [:d],
      adds: [
        [
          [:e, my_exec_context.method(:e)],
          :replace, :d
        ]
      ]
    )

    # patch three levels down.
    top_pipe_deeply_patched = Trailblazer::Circuit::Patch.(
      my_top_pipe,
      [:abc, :ab],
      adds: [
        [
          [:e, my_exec_context.method(:e)],
          :after, :a
        ]
      ]
    )

    assert_run my_top_pipe, seq: [:d, :c, :a, :b]
    assert_run my_new_top_pipe, seq: [:e, :c, :a, :b]
    assert_run top_pipe_deeply_patched, seq: [:d, :c, :a, :e, :b]
  end
end
