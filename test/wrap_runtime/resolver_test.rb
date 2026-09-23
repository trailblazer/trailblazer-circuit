require "test_helper"

class WrapRuntimeResolveTest < Minitest::Spec
  it "The {:wrap_runtime} resolver examines each node and evaluates conditions. The default_extension_set is only applied if all conditions are true" do
    my_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:a, T.def_tasks(:a, success_signal: "Right").method(:a)],
    )
    my_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:A, my_circuit, Trailblazer::Circuit::Processor, options: {is_circuit: true}],
      [:b, T.def_tasks(:b, success_signal: "Right").method(:b)],
    )

    assert_run my_circuit, seq: [:a, :b], terminus: "Right"


    class MyExtension < Struct.new(:id)
      def call(task, lib_ctx, flow_options, signal, node:, id:, **circuit_options)
        # puts "@@@@@ #{node.inspect}" # we are seeing ourselves because the node we're "tracing" is one after us.
        return lib_ctx, flow_options.merge(self.id => id), signal
      end

      # Called through WrapRuntime::Runner.
      # This is the builder.
      def self.call(id:, **attrs)
        my_adapter = MyExtension.new(id) # we will store ...:a because this extension is executed after the NodeWrap extension.

        [
          # in order to access circuit_options, we simply are our own adapter
          [:capture_before, Trailblazer::Circuit::Node[nil, my_adapter, options: {already_wrapped: true}], :before, nil],
        ]
      end
    end

    my_tracing_ext = Trailblazer::Circuit::WrapRuntime.Extension(adds: MyExtension)
    my_extensions = Trailblazer::Circuit::WrapRuntime::Extension::Set.new(
      [
        Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap,
        my_tracing_ext
      ]
    )

    my_wrap_runtime_resolver = Trailblazer::Circuit::WrapRuntime::Extension::Resolver.new(
      default_extension_set: my_extensions,
      conditions: [
        Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Resolver::CONDITION,
        ->(node:, **) { node.to_h[:options][:is_circuit] },
        # ->(node:, **) { puts "condition #{node}"; true }
      ]
    )

    lib_ctx, flow_options, signal = assert_run my_circuit,
      circuit_options: {runner: Trailblazer::Circuit::WrapRuntime::Runner, wrap_runtime: my_wrap_runtime_resolver},
      seq: [:a, :b], terminus: "Right"

    assert_equal flow_options, {"...A" => :capture_before}
  end

  it "the {:wrap_runtime} resolver can access {:id}" do
    raise
  end
end
