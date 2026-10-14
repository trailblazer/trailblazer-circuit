require "test_helper"

# TODO: maybe we should test more about what the Conditions etc receive?
class WrapRuntimeExtensionDispatcherTest < Minitest::Spec
  it "The {:wrap_runtime} dispatcher lets the Extensions examine each node and evaluate conditions. if all conditions are true, the extension is applied" do
    my_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:a, T.def_tasks(:a, success_signal: "Right").method(:a)],
    )

    my_a_circuit_node = Trailblazer::Circuit::Node[my_circuit, Trailblazer::Circuit::Processor, options: {is_circuit: true}]

    my_circuit = Trailblazer::Circuit::Builder.Pipeline(
      [:A, node: my_a_circuit_node],
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

    my_tracing_ext = Trailblazer::Circuit::WrapRuntime::Extension::AddsInstructions.new(MyExtension)
    my_extensions = Trailblazer::Circuit::WrapRuntime::Extension::Chain.new(
      [
        Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap,
        my_tracing_ext
      ]
    )

    my_wrap_runtime_resolver = Trailblazer::Circuit::WrapRuntime::Extension.new(
      Trailblazer::Circuit::WrapRuntime::Extension::Conditions.new(
        [
          Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::CONDITION,
          ->(node:, **) { node.to_h[:options][:is_circuit] },
        ]
      ),
      my_extensions,
    )

    lib_ctx, flow_options, signal = assert_run my_circuit,
      circuit_options: {runner: Trailblazer::Circuit::WrapRuntime::Runner, wrap_runtime: my_wrap_runtime_resolver},
      seq: [:a, :b], terminus: "Right"

    assert_equal flow_options, {Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Id.new(:A, my_a_circuit_node) => :capture_before}
  end
end
