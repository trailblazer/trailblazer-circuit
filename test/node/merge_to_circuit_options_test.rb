require "test_helper"

class MergeToCircuitOptions_UnitTest < Minitest::Spec
  it "merges {:exec_context} into circuit_options" do
    # DISCUSS: currently, we can only be merge_to_circuit_options or merge_to_lib_ctx.

    my_exec_context = T.def_tasks(:a, success_signal: Right)

    my_node = Trailblazer::Circuit::Node::MergeToCircuitOptions[
      nil,
      :a,
      Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod,
      {exec_context: my_exec_context}
    ]

    lib_ctx, flow_options, signal = my_node.({}, {application_ctx: {seq: []}}, nil, {})

    assert_equal lib_ctx, {}
    assert_equal flow_options, {application_ctx: {seq: [:a]}}
    assert_equal signal, Right
  end
end

class MergeToCircuitOptions_IntegrationTest < Minitest::Spec
  it "circuit_options per branch cannot be altered, they're passed down but can be locally overridden" do
    my_exec_context_ab = T.def_tasks(:a, :b, :d, success_signal: Right)
    my_exec_context_c = T.def_tasks(:c, success_signal: Right)
    my_exec_context_z = T.def_tasks(:z, success_signal: Right)
    my_exec_context_xyuv = T.def_tasks(:x, :y, :u, :v, success_signal: Right)

    my_pipe_3 = Trailblazer::Circuit::Builder.Pipeline(
      [:c, :c, lib_interface::InstanceMethod, exec_context: my_exec_context_c],
      [:v, :v, lib_interface::InstanceMethod], # we use our parent pipe's {:exec_context} that was set in {my_pipe_1}!
    )

    my_pipe_2 = Trailblazer::Circuit::Builder.Pipeline(
      [:x, :x, lib_interface::InstanceMethod],
      [:z, :z, lib_interface::InstanceMethod, exec_context: my_exec_context_z],
      [:y, :y, lib_interface::InstanceMethod],
      [:v, my_pipe_3, Trailblazer::Circuit::Processor],
      [:u, :u, lib_interface::InstanceMethod],
    )

    my_pipe_1 = Trailblazer::Circuit::Builder.Pipeline(
      [:a, :a, lib_interface::InstanceMethod],
      [:z, my_pipe_2, Trailblazer::Circuit::Processor, exec_context: my_exec_context_xyuv],
      [:b, :b, lib_interface::InstanceMethod],
    )

    assert_run my_pipe_1,
      seq: [:a, :x, :z, :y, :c, :v, :u, :b],
      circuit_options: {exec_context: my_exec_context_ab},
      terminus: Right
  end
end
