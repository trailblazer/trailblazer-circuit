require "test_helper"

class NodeWrapTest < Minitest::Spec
  let(:my_extension) do
    ->(lib_ctx, flow_options, signal, node, id) do
      # lib_ctx      = Helper.add_to_seq_in_lib_ctx(lib_ctx, id)
      # flow_options = Helper.add_to_seq(flow_options, id)
      signal       = Helper.add_to_seq(signal, id)

      return lib_ctx, flow_options, signal, node, id
    end
  end

  let(:node_wrap_extension) { Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::EXTENSION }

  it "NodeWrap: it creates a virtual pipe for particular nodes.
our my_extension is called after the wrapped node is created, meaning we see the updated NodeWrap::Id.
" do
    dispatcher_chain = Trailblazer::Circuit::WrapRuntime::Extension::Chain.new([node_wrap_extension, my_extension])

    top_extension = Trailblazer::Circuit::WrapRuntime::Extension.new(
      ->(*, id) { [:Create, :d].include?(id) },
      dispatcher_chain,
    )

    my_node = Trailblazer::Circuit::Node[my_pipe, Trailblazer::Circuit::Processor]

    lib_ctx, flow_options, signal = assert_run nil, :Create,
      node: my_node,
      flow_options: Trailblazer::Circuit::WrapRuntime::Runner.new(wrap_runtime: top_extension),
      signal:       {seq: ["signal",]},
      # expected:
      seq: [:a, :b, :c, :d, :e],
      terminus: {seq: ["signal",
        Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Id.new(:Create, my_node),
        Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Id.new(:d, my_node.task.nodes["b|"].task.nodes["d|"].task.nodes[:d]),
      ]}
  end

  it "we can add steps into the virtual pipe
we can see the actual wrapped ID via id.to_sym
the adds_producer sees the same incoming interface
" do
    my_tracer = Struct.new(:id) do
      def call(lib_ctx, flow_options, signal, target_ctx:, **)
        signal       = Helper.add_to_seq(signal, [id, target_ctx.clone])

        return lib_ctx, flow_options, signal
      end
    end

    my_adds_producer = ->(*, node, id) do
      [
        [
          :my_trace_step, Trailblazer::Circuit::Node[my_tracer.new(id), Trailblazer::Circuit::Task::Adapter::LibInterface],
          :before, :"task_wrap.call_task"
        ]
      ]
    end

    my_adds_extension = Trailblazer::Circuit::WrapRuntime::Extension(
      ->(*, id) { [:Create, :d].include?(id.to_sym) },
      adds_producer: my_adds_producer
    )

    # NodeWrap is always invoked, our "tracing" only for :Create and :d.
    dispatcher_chain = Trailblazer::Circuit::WrapRuntime::Extension::Chain.new([node_wrap_extension, my_adds_extension])

    my_node = Trailblazer::Circuit::Node[my_pipe, Trailblazer::Circuit::Processor]

    lib_ctx, flow_options, signal = assert_run nil, :Create,
      node: my_node,
      flow_options: Trailblazer::Circuit::WrapRuntime::Runner.new(wrap_runtime: dispatcher_chain),
      signal:       {seq: ["signal",]},
      # expected:
      seq: [:a, :b, :c, :d, :e],
      terminus: {
        seq: [
          "signal",
          # [:Create, {seq: []}], [:d, {seq: [:a, :b, :c]}]]
          [
            Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Id.new(:Create, my_node),
            {seq: []}
          ],
          [
            Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Id.new(:d, my_node.task.nodes["b|"].task.nodes["d|"].task.nodes[:d]),
            {seq: [:a, :b, :c]}
          ],
        ]
      }
  end

end
