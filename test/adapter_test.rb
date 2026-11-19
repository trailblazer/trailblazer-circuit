require "test_helper"

# Adapter, Invoker, Caller, Interface
class AdapterTest < Minitest::Spec
  Captured = Struct.new(:data)

  let (:my_step_interface_exec_context) do
    Class.new do
      def my_model(ctx, params:, **options)
        ctx[:model] = Captured.new(
          [
            ctx,
            params,
            options
          ].collect { |obj| obj.inspect }
        )

        return nil
      end

    end.new
  end

  let(:my_lib_interface_exec_context) do
    Class.new do
      def my_model_input(lib_ctx, flow_options, signal, **options)
        lib_ctx = lib_ctx.merge(captured: Captured.new(
          [
            lib_ctx,
            flow_options.to_h,
            signal,
            options,
          ]#.collect { |obj| CU.inspect(obj) }
        ))

        return lib_ctx, flow_options, signal
      end
    end.new
  end

  def assert_step_interface(node)
    target_ctx = {params: {id: 1}, slug: 9}

    expected_capture = Captured.new([{params: {id: 1}, slug: 9}.inspect, {id: 1}.inspect, {slug: 9}.inspect]).freeze

    lib_ctx, flow_options, signal = assert_run aggregate: [], node: node, target_ctx: target_ctx,
      expected_target_variables: {
        model: expected_capture
      }

    # Unfortunately, application_ctx is mutated, that's how step interface works.
    assert_equal target_ctx, {
      params: {:id=>1},
      slug: 9,
      model:  expected_capture,
    }
  end

  def assert_lib_interface(node, expected_lib_ctx_variables:)
    # target_ctx = {params: {id: 1}, slug: 9}
    lib_ctx, _ = assert_run node: node, aggregate: [], seq: []

    expected_lib_ctx = {aggregate: [], target_ctx: {seq: []}}.merge(expected_lib_ctx_variables)

    assert_equal lib_ctx, {
      aggregate: [],
      target_ctx: {seq: []},
      captured: Captured.new(
        [
          expected_lib_ctx,
          {},
          nil,
          expected_lib_ctx
        ]
      )
    }
  end

  it "StepInterface::InstanceMethod" do
    node = Trailblazer::Circuit::Builder.Node(:my_model, Trailblazer::Circuit::Task::Adapter::StepInterface::InstanceMethod, exec_context: my_step_interface_exec_context)

    assert_step_interface(node)
  end

  it "StepInterface" do
    node = Trailblazer::Circuit::Node[my_step_interface_exec_context.method(:my_model), Trailblazer::Circuit::Task::Adapter::StepInterface]

    assert_step_interface(node)
  end

  it "LibInterface::InstanceMethod" do
    node = Trailblazer::Circuit::Builder.Node(:my_model_input, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, exec_context: my_lib_interface_exec_context, copy_to_outer_ctx: [:captured])

    assert_lib_interface(node, expected_lib_ctx_variables: {exec_context: my_lib_interface_exec_context})
  end

  it "LibInterface" do
    node = Trailblazer::Circuit::Node[my_lib_interface_exec_context.method(:my_model_input), Trailblazer::Circuit::Task::Adapter::LibInterface]

    assert_lib_interface(node, expected_lib_ctx_variables: {})
  end
end
