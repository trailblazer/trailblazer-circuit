require "test_helper"

class NodeRunnerTest < Minitest::Spec
  it "{Runner.call}" do
    my_pipe = Pipeline(
      [:a, :a, _A::Circuit::Task::Adapter::StepInterface::InstanceMethod],
      [:b, :b, _A::Circuit::Task::Adapter::StepInterface::InstanceMethod],
      [:c, :c, _A::Circuit::Task::Adapter::StepInterface::InstanceMethod],
    )

    my_pipe_node = _A::Circuit::Node::Scoped[:my_pipe_node, my_pipe, _A::Circuit::Processor]
    runner = _A::Circuit::Node::Runner

    my_exec_context = T.def_steps(:a, :b, :c)

    lib_ctx, flow_options = runner.(my_pipe_node, {exec_context: my_exec_context}, {application_ctx: {seq: []}}, nil,
      runner: runner,
      context_implementation: Trailblazer::Circuit::Context,
    )

    assert_equal flow_options[:application_ctx][:seq], [:a, :b, :c]
  end

  it "{:start_node} can be passed which is then used by Processor" do
    my_pipe = Pipeline(
      [:a, :a, _A::Circuit::Task::Adapter::StepInterface::InstanceMethod],
      [:b, :b, _A::Circuit::Task::Adapter::StepInterface::InstanceMethod],
      [:c, :c, _A::Circuit::Task::Adapter::StepInterface::InstanceMethod],
    )

    my_pipe_node = _A::Circuit::Node::Scoped[:my_pipe_node, my_pipe, _A::Circuit::Processor]
    runner = _A::Circuit::Node::Runner

    my_exec_context = T.def_steps(:a, :b, :c)

    lib_ctx, flow_options, signal = runner.(my_pipe_node, {exec_context: my_exec_context}, {application_ctx: {seq: []}}, nil, runner: runner,
      start_node: [:b, my_pipe.config[:b]],
      context_implementation: Trailblazer::Circuit::Context,
    )

    assert_equal flow_options[:application_ctx][:seq], [:b, :c]
  end

  # DISCUSS: move to {internal-compat/}?
  it "we can build our own Node to implement {:start_node} for a nested circuit" do
    my_exec_context = T.def_tasks(:a, :b, :c, :d, :e, :f, success_signal: Right)

    my_nested_pipe = Pipeline(
      [:d, :d],
      [:e, :e],
      [:f, :f],
    )

    my_node_that_knows_start_node = Class.new(_A::Circuit::Node) do
      def call(lib_ctx, flow_options, signal, **circuit_options)
        start_node_id = flow_options[:start_node_id_for_b]

        super(lib_ctx, flow_options, signal, **circuit_options, start_node: [start_node_id, task.config[start_node_id]])
      end
    end.new(id: :b, task: my_nested_pipe, interface: _A::Circuit::Processor)

    my_pipe = Pipeline(
      [:a, :a],
      [:b, node: my_node_that_knows_start_node],
      [:c, :c],
    )

    assert_run my_pipe, seq: [:a, :d, :e, :f, :c], exec_context: my_exec_context, flow_options: {start_node_id_for_b: :d}, terminus: Right
    assert_run my_pipe, seq: [:a, :e, :f, :c], exec_context: my_exec_context, flow_options: {start_node_id_for_b: :e}, terminus: Right
  end
end
