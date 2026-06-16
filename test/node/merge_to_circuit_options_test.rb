require "test_helper"

class MergeToCircuitOptions_UnitTest < Minitest::Spec
  it "what" do
    # DISCUSS: currently, we can only be merge_to_circuit_options or merge_to_lib_ctx.


    my_exec_context = T.def_tasks(:a, success_signal: Right)

    my_node = Trailblazer::Circuit::Node::MergeToCircuitOptions[
      nil,
      :a,
      Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod_CircuitOptions,
      {exec_context: my_exec_context}
    ]

    lib_ctx, flow_options, signal = my_node.({}, {application_ctx: {seq: []}}, nil, {})

    assert_equal lib_ctx, {}
    assert_equal flow_options, {application_ctx: {seq: [:a]}}
    assert_equal signal, Right
  end
end
