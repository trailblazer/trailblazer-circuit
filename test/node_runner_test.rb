require "test_helper"

class NodeRunnerTest < Minitest::Spec
  let(:my_exec_context) { T.def_tasks(:a, :b, :c, success_signal: nil) }

  it "{Runner.call}" do
    my_pipe = Pipeline(
      [:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      [:b, :b, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      [:c, :c, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
    )

    my_pipe_node = _A::Circuit::Node::Scoped[:my_pipe_node, my_pipe, _A::Circuit::Processor]
    runner = _A::Circuit::Node::Runner

    lib_ctx, flow_options = runner.(my_pipe_node, {target_ctx: {seq: []}}, {}, nil,
      runner: runner,
      context_implementation: Trailblazer::Circuit::Context,
      exec_context: my_exec_context
    )

    assert_equal lib_ctx[:target_ctx][:seq], [:a, :b, :c]
  end

  it "{:start_tuple} can be passed which is then used by Processor" do
    my_pipe = Pipeline(
      [:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      [:b, :b, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      [:c, :c, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
    )

    my_pipe_node = _A::Circuit::Node[:my_pipe_node, my_pipe, _A::Circuit::Processor]
    runner = _A::Circuit::Node::Runner

    lib_ctx, flow_options, signal = runner.(my_pipe_node, {target_ctx: {seq: []}}, {}, nil,
      {
        exec_context: my_exec_context,
        runner: runner,
        start_tuple: [:b, my_pipe.nodes[:b]],
      }
    )

    assert_equal lib_ctx[:target_ctx][:seq], [:b, :c]
  end

  # DISCUSS: move to {internal-compat/}?
  it "we can build our own Node to implement {:start_tuple} for a nested circuit" do
    my_exec_context = T.def_tasks(:a, :b, :c, :d, :e, :f, success_signal: Right)

    my_nested_pipe = Pipeline(
      [:d, my_exec_context.method(:d)],
      [:e, my_exec_context.method(:e)],
      [:f, my_exec_context.method(:f)],
    )

    my_node_that_knows_start_tuple = Class.new(_A::Circuit::Node) do
      def call(lib_ctx, flow_options, signal, circuit_options)
        start_tuple_id = flow_options[:start_tuple_id_for_b]

        circuit_options = circuit_options.merge(start_tuple: [start_tuple_id, task.nodes[start_tuple_id]])

        super(lib_ctx, flow_options, signal, circuit_options)
      end
    end.new(id: :b, task: my_nested_pipe, interface: _A::Circuit::Processor)

    my_pipe = Pipeline(
      [:a, my_exec_context.method(:a)],
      [:b, node: my_node_that_knows_start_tuple],
      [:c, my_exec_context.method(:c)],
    )

    assert_run my_pipe, seq: [:a, :d, :e, :f, :c], exec_context: my_exec_context, flow_options: {start_tuple_id_for_b: :d}, terminus: Right
    assert_run my_pipe, seq: [:a, :e, :f, :c], exec_context: my_exec_context, flow_options: {start_tuple_id_for_b: :e}, terminus: Right
  end
end
