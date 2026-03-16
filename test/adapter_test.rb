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
    assert_equal ctx, {aggregate: []}
    assert_equal flow_options, {
      :application_ctx=>{
        params: {:id=>1},
        slug: 9,
        model:  Captured.new(["{:params=>{:id=>1}, :slug=>9}", "{:id=>1}", "{:slug=>9}"]),
      },
      :trace_ctx=>{:stack=>[]}
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
    node = _A::Circuit::Node::Scoped[id: :my_model, task: :my_model, interface: _A::Circuit::Task::Adapter::StepInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: my_step_interface_exec_context}]

    assert_step_interface(node)
  end

  it "StepInterface" do
    node = _A::Circuit::Node::Scoped[id: :my_model, task: my_step_interface_exec_context.method(:my_model), interface: _A::Circuit::Task::Adapter::StepInterface]

    assert_step_interface(node)
  end

  it "LibInterface::InstanceMethod" do
    node = _A::Circuit::Node::Scoped[id: :my_model_input, task: :my_model_input, interface: _A::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: my_lib_interface_exec_context}, copy_to_outer_ctx: [:captured]]

    assert_lib_interface(node, original_ctx: {aggregate: [], exec_context: my_lib_interface_exec_context})
  end

  it "LibInterface" do
    node = _A::Circuit::Node::Scoped[id: :my_model_input, task: my_lib_interface_exec_context.method(:my_model_input), interface: _A::Circuit::Task::Adapter::LibInterface, copy_to_outer_ctx: [:captured]]

    assert_lib_interface(node, original_ctx: ctx = {aggregate: []})
  end
end
