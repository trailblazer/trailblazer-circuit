require "test_helper"

# Make sure that we can build something like Wrap() and Rescue() easily.
class WrapTest < Minitest::Spec
  it "what" do
    my_steps = T.def_steps(:a, :b, :c)
    my_raise_step = ->(ctx, do_raise: false, **) { ctx[:seq] << :d; raise if do_raise }

    wrapped_pipe = _A::Circuit::Builder.Pipeline(
      [:a, my_steps.method(:a), _A::Circuit::Task::Adapter::StepInterface],
      [:d, my_raise_step, _A::Circuit::Task::Adapter::StepInterface],
    )

    my_node_with_wrap = Class.new(_A::Circuit::Node::Scoped) do
      def call(lib_ctx, flow_options, signal, **)
      begin
        lib_ctx, flow_options, signal = super
      rescue
        flow_options[:application_ctx][:exception] = $!
      end

        return lib_ctx, flow_options, signal
      end
    end.new(id: :wrap_pipe, task: wrapped_pipe, interface: _A::Circuit::Processor)

    wrap_pipe = _A::Circuit::Builder.Pipeline(
      [:b,    my_steps.method(:b), _A::Circuit::Task::Adapter::StepInterface],
      [:wrap, node: my_node_with_wrap],
      [:c,    my_steps.method(:c), _A::Circuit::Task::Adapter::StepInterface],
    )

    lib_ctx, flow_options = assert_run wrap_pipe, seq: [:b, :a, :d, :c]
    assert_nil flow_options[:application_ctx][:exception]

    # raise
    lib_ctx, flow_options = assert_run wrap_pipe, seq: [:b, :a, :d, :c], do_raise: true
    assert_equal flow_options[:application_ctx][:exception].inspect, %(RuntimeError)
  end
end
