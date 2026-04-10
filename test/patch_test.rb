require "test_helper"

module Trailblazer
  class Circuit
    module Patch
      def self.call(circuit, path, adds:)
        # traverse deeper if {path}
        if path.any?
          id, *path = path

          node_for_id = circuit.nodes[id]
          circuit_for_id = node_for_id.task # DISCUSS: use Introspect?

          # traverse
          new_circuit_for_id = call(circuit_for_id, path, adds: adds)

          # Replace the currently traversed nested node with the patched version.
          adds = [
            [
              node_for_id.class.new(**node_for_id.to_h, task: new_circuit_for_id), # TODO: provide API from Node.
              :replace, id
            ]
          ]
        end

        return Adds.(circuit, *adds)
      end
    end
  end
end

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
      [],
      adds: [
        [
          Trailblazer::Circuit::Node[:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface], # TODO: provide shortcut from Builder.
          :replace, :d
        ]
      ]
    )

    # patch two levels down.
    pipe_two_levels_patched = Trailblazer::Circuit::Patch.(
      my_top_pipe,
      [:abc],
      adds: [
        [
          Trailblazer::Circuit::Node[:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface],
          :after, :c
        ]
      ]
    )

    # patch three levels down.
    top_pipe_deeply_patched = Trailblazer::Circuit::Patch.(
      my_top_pipe,
      [:abc, :ab],
      adds: [
        [
          Trailblazer::Circuit::Node[:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface],
          :after, :a
        ]
      ]
    )

    assert_run my_top_pipe, seq: [:d, :c, :a, :b]
    assert_run my_new_top_pipe, seq: [:e, :c, :a, :b]
    assert_run top_pipe_deeply_patched, seq: [:d, :c, :a, :e, :b]
    assert_run pipe_two_levels_patched, seq: [:d, :c, :e, :a, :b]
  end
end
