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
          ].collect { |obj| CU.inspect(obj) }
        )
      end
    end.new
  end

  let(:my_lib_interface_exec_context) do
    Class.new do
      def my_model_input(ctx, flow_options, signal, **options)
        ctx = ctx.merge(captured: Captured.new(
          [
            ctx,
            flow_options,
            signal,
            options,
          ]#.collect { |obj| CU.inspect(obj) }
        ))

        return ctx, flow_options, signal
      end
    end.new
  end

  def assert_step_interface(node)
    application_ctx = {params: {id: 1}, slug: 9}

    ctx, flow_options, signal = _A::Circuit::Node::Runner.(
      node,
      {aggregate: []}, # let's assume this is part of the local processing pipeline and from one of the recent steps.
      {
        trace_ctx: {stack: []},
      },
      application_ctx,
      runner: _A::Circuit::Node::Runner,
      context_implementation: Trailblazer::Circuit::Context,
    )

    expected_capture = Captured.new(["{:params=>{:id=>1}, :slug=>9}", "{:id=>1}", "{:slug=>9}"]).freeze

    assert_equal signal, expected_capture
    assert_equal ctx, {aggregate: []}
    assert_equal flow_options, {
      :trace_ctx=>{:stack=>[]}
    }
    # Unfortunately, application_ctx is mutated, that's how step interface works.
    assert_equal application_ctx, {
      params: {:id=>1},
      slug: 9,
      model:  expected_capture,
    }
  end

  def assert_lib_interface(node, original_ctx:)
    ctx, flow_options, signal = _A::Circuit::Node::Runner.(
      node,
      {aggregate: []}, # let's assume this is part of the local processing pipeline and from one of the recent steps.
      {
        application_ctx: {params: {id: 1}, slug: 9},
        trace_ctx: {stack: []},
      },
      nil,
      runner: _A::Circuit::Node::Runner,
      context_implementation: Trailblazer::Circuit::Context,
    )

    assert_equal signal, nil
    assert_equal ctx, {aggregate: [], captured:
      Captured.new(
        [
          original_ctx,
          {:application_ctx=>{:params=>{:id=>1}, :slug=>9}, :trace_ctx=>{:stack=>[]}},
          nil,
          original_ctx
        ]
      )
    }

    assert_equal flow_options, {
      :application_ctx=>{
        params: {:id=>1},
        slug: 9,
      },
      :trace_ctx=>{:stack=>[]}
    }
  end

  it "StepInterface::InstanceMethod" do
    node = _A::Circuit::Node::MergeToCircuitOptions[nil, :my_model, _A::Circuit::Task::Adapter::StepInterface::InstanceMethod, exec_context: my_step_interface_exec_context]

    assert_step_interface(node)
  end

  it "StepInterface" do
    node = _A::Circuit::Node[:my_model, my_step_interface_exec_context.method(:my_model), _A::Circuit::Task::Adapter::StepInterface]

    assert_step_interface(node)
  end

  it "LibInterface::InstanceMethod" do
    node = _A::Circuit::Node::MergeToCircuitOptions[:my_model_input, :my_model_input, _A::Circuit::Task::Adapter::LibInterface::InstanceMethod, exec_context: my_lib_interface_exec_context]

    assert_lib_interface(node, original_ctx: {aggregate: []})
  end

  it "LibInterface" do
    node = _A::Circuit::Node[:my_model_input, my_lib_interface_exec_context.method(:my_model_input), _A::Circuit::Task::Adapter::LibInterface]

    assert_lib_interface(node, original_ctx: ctx = {aggregate: []})
  end
end
