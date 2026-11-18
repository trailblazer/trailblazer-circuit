require "test_helper"

class NodeRunnerTest < Minitest::Spec
  let(:my_exec_context) { T.def_tasks(:a, :b, :c, success_signal: nil) }

  it "{Runner.call}" do
    my_pipe = Pipeline(
      [:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      [:b, :b, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      [:c, :c, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
    )

    my_pipe_node = _A::Circuit::Node[my_pipe, _A::Circuit::Processor]
    runner = _A::Circuit::Node::Runner.new

    lib_ctx, flow_options = runner.({target_ctx: {seq: []}, exec_context: my_exec_context}, runner, nil, my_pipe_node, nil)

    assert_equal lib_ctx[:target_ctx][:seq], [:a, :b, :c]
  end

  it "{:start_tuple} can be passed which is then used by Processor" do
    skip "we have to build that with an overridden circuit"
    my_pipe = Pipeline(
      [:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      [:b, :b, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      [:c, :c, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
    )

    my_pipe_node = _A::Circuit::Node[my_pipe, _A::Circuit::Processor]
    runner = _A::Circuit::Node::Runner

    lib_ctx, flow_options, signal = runner.({target_ctx: {seq: []}}, {}, nil,
      exec_context: my_exec_context,
      runner: runner,
      node: my_pipe_node,
      start_tuple: [:b, my_pipe.nodes[:b]],
    )

    assert_equal lib_ctx[:target_ctx][:seq], [:b, :c]
  end

  # DISCUSS: move to {internal-compat/}?
  it "we can build our own Node to implement {:start_tuple} for a (nested) circuit" do
    my_exec_context = T.def_tasks(:a, :b, :c, :d, :e, :f, success_signal: Right)

    my_nested_pipe = Pipeline(
      [:d, my_exec_context.method(:d)],
      [:e, my_exec_context.method(:e)],
      [:f, my_exec_context.method(:f)],
    )

    my_node_that_knows_start_tuple = Class.new(Trailblazer::Circuit::Node) do
      def call(lib_ctx, flow_options, signal)
        start_tuple_id = lib_ctx[:start_tuple_id_for_b]

        new_circuit = task.clone
        new_circuit.start_tuple = [start_tuple_id, task.nodes[start_tuple_id]]

        # new_node = self.merge(bla: 1)
        new_node = Trailblazer::Circuit::Node[task, Trailblazer::Circuit::Processor]
        new_node.task = new_circuit

        new_node.(lib_ctx, flow_options, signal)
      end
    end[my_nested_pipe, Trailblazer::Circuit::Processor]

    my_pipe = Pipeline(
      [:a, my_exec_context.method(:a)],
      [:b, node: my_node_that_knows_start_tuple],
      [:c, my_exec_context.method(:c)],
    )

    assert_run my_pipe, seq: [:a, :d, :e, :f, :c], start_tuple_id_for_b: :d, terminus: Right
    assert_run my_pipe, seq: [:a, :e, :f, :c], start_tuple_id_for_b: :e, terminus: Right
  end
end
