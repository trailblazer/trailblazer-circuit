require "test_helper"

# FIXME: add test for a non Node node :D
# add test for specific tasks

class WrapRuntimeTest < Minitest::Spec
  it "the WrapRuntime::Runner executes its {:wrap_runtime} per node, giving us a way to run logic *before* the actual node invocation.
the extension sees the runner interface.
(incoming args) we test that we see the correct {lib_ctx, flow_options, signal} in each extension invocation.
(order) we test the order is correct (extension before task).
" do
    my_ext = ->(lib_ctx, flow_options, signal, node, id) do
      lib_ctx      = Helper.add_to_seq_in_lib_ctx(lib_ctx, ">#{id}")
      flow_options = Helper.add_to_seq(flow_options, id)
      signal       = Helper.add_to_seq(signal, id)

      return lib_ctx, flow_options, signal, node, id
    end

    lib_ctx, flow_options, signal = assert_run my_pipe, :Create,
      flow_options: Trailblazer::Circuit::WrapRuntime::Runner.new(wrap_runtime: my_ext, seq: ["flow_options"]),
      signal:       {seq: ["signal"]},
      # expected:
      seq: [">Create", ">a", :a, ">b|", ">b", :b, ">c|", ">c", :c, ">d|", ">d", :d, ">e", :e],
      terminus: {seq: ["signal", :Create, :a, "b|", :b, "c|", :c, "d|", :d, :e]}

    assert_equal flow_options.to_h[:seq], ["flow_options", :Create, :a, "b|", :b, "c|", :c, "d|", :d, :e]
  end

  it "an extension can see the {node, id} tuple" do
    my_ext = ->(lib_ctx, flow_options, signal, node, id) do
      lib_ctx = Helper.add_to_seq_in_lib_ctx(lib_ctx, [id, node])

      return lib_ctx, flow_options, signal, node, id
    end

    my_pipe     = my_pipe()
    my_top_node = Trailblazer::Circuit::Node[my_pipe, Trailblazer::Circuit::Processor]

    lib_ctx, flow_options, signal = assert_run nil, :Create, node: my_top_node,
      flow_options: Trailblazer::Circuit::WrapRuntime::Runner.new(wrap_runtime: my_ext),
      # expected:
      seq: [
        [:Create, my_top_node],
        [:a, my_pipe.nodes[:a]],
        :a,
        ["b|", my_pipe.nodes["b|"]],
        [:b, my_pipe.nodes["b|"].task.nodes[:b]],
        :b,
        ["c|", my_pipe.nodes["b|"].task.nodes["c|"]],
        [:c, my_pipe.nodes["b|"].task.nodes["c|"].task.nodes[:c]],
        :c,
        ["d|", my_pipe.nodes["b|"].task.nodes["d|"]],
        [:d, my_pipe.nodes["b|"].task.nodes["d|"].task.nodes[:d]],
        :d,
        [:e, my_pipe.nodes[:e]],
        :e,
      ]
  end

  it "an extension can return altered arguments, allowing to change the node that is invoked by the Runner" do
    # the "extended node" adds an ID to seq and then calls the original node.
    # that's just a test, and shouldn't be done in the wild, but it's also not wrong.
    my_extension_node_class = Struct.new(:id, :original_node) do
      def call(lib_ctx, flow_options, signal)
        lib_ctx = Helper.add_to_seq_in_lib_ctx(lib_ctx, id)

        original_node.call(lib_ctx, flow_options, signal)
      end
    end

    my_ext = ->(lib_ctx, flow_options, signal, node, id) do
      node = my_extension_node_class.new([id], node)

      # simly replace the current node.
      return lib_ctx, flow_options, signal, node, id
    end

    lib_ctx, flow_options, signal = assert_run my_pipe, :Create,
      flow_options: Trailblazer::Circuit::WrapRuntime::Runner.new(wrap_runtime: my_ext),
      # expected:
      seq: [[:Create], [:a], :a, ["b|"], [:b], :b, ["c|"], [:c], :c, ["d|"], [:d], :d, [:e], :e]
  end

  #
  # Extension tests
  #

  it "we can change the current node with a WrapRuntime::Extension with a condition and an {:adds} producer
we place a new step after the b and d pipe" do
    my_adds_producer = ->(*, id) do
      [
        [
          :capture_after, Trailblazer::Circuit::Node[T.def_task(:"after-#{id}", success_signal: nil), Trailblazer::Circuit::Task::Adapter::LibInterface, options: {already_wrapped: true}],
          :after
        ],
      ]
    end

    tw_trace_extension = Trailblazer::Circuit::WrapRuntime::Extension(
      ->(*, node, id) { ["b|", "d|"].include?(id) },
      adds_producer: my_adds_producer
    )

    assert_run my_pipe, :Create, seq: [:a, :b, :c, :d, :"after-d|", :"after-b|", :e],
      flow_options: Trailblazer::Circuit::WrapRuntime::Runner.new(wrap_runtime: tw_trace_extension)
  end

  it "in a Chain, the next extension sees the args from the predecessor" do
    my_first_ext = ->(lib_ctx, flow_options, signal, node, id) do
      lib_ctx      = Helper.add_to_seq_in_lib_ctx(lib_ctx, ">#{id}")
      flow_options = Helper.add_to_seq(flow_options, id)
      signal       = Helper.add_to_seq(signal, ">#{id}")

      return [lib_ctx], [flow_options], [signal], [node], [id]
    end

    my_second_ext = ->((lib_ctx, _), (flow_options, _), (signal, _), (node, _), (id, _)) do
      lib_ctx      = Helper.add_to_seq_in_lib_ctx(lib_ctx, "@#{id}")
      flow_options = Helper.add_to_seq(flow_options, id)
      signal       = Helper.add_to_seq(signal, "@#{id}")

      return lib_ctx, flow_options, signal, node, id
    end

    dispatcher_chain = Trailblazer::Circuit::WrapRuntime::Extension::Chain.new([my_first_ext, my_second_ext])

    lib_ctx, flow_options, signal = assert_run my_pipe, :Create,
      flow_options: Trailblazer::Circuit::WrapRuntime::Runner.new(wrap_runtime: dispatcher_chain, seq: ["flow_options"]),
      signal:       {seq: ["signal"]},
      # expected:
      seq: [">Create", "@Create", ">a", "@a", :a, ">b|", "@b|", ">b", "@b", :b, ">c|", "@c|", ">c", "@c", :c, ">d|", "@d|", ">d", "@d", :d, ">e", "@e", :e],
      terminus: {seq: ["signal", ">Create", "@Create", ">a", "@a", ">b|", "@b|", ">b", "@b", ">c|", "@c|", ">c", "@c", ">d|", "@d|", ">d", "@d", ">e", "@e"]}

    assert_equal flow_options.to_h[:seq], ["flow_options", :Create, :Create, :a, :a, "b|", "b|", :b, :b, "c|", "c|", :c, :c, "d|", "d|", :d, :d, :e, :e]
  end

  let(:my_extension) do
    ->(lib_ctx, flow_options, signal, node, id) do
      lib_ctx      = Helper.add_to_seq_in_lib_ctx(lib_ctx, ">#{id}")
      flow_options = Helper.add_to_seq(flow_options, id)
      signal       = Helper.add_to_seq(signal, id)

      return lib_ctx, flow_options, signal, node, id
    end
  end

  it "an Extension has a condition and an extension chain, the latter is only run when the condition's met
we test {Extension.new} here, not the Extension() builder
" do
    dispatcher_chain = Trailblazer::Circuit::WrapRuntime::Extension::Chain.new([my_extension])

    my_extension = Trailblazer::Circuit::WrapRuntime::Extension.new(
      ->(*, id) { [:Create, :c].include?(id) },
      dispatcher_chain
    )

    lib_ctx, flow_options, signal = assert_run my_pipe, :Create,
      flow_options: Trailblazer::Circuit::WrapRuntime::Runner.new(wrap_runtime: my_extension, seq: ["flow_options"]),
      signal:       {seq: ["signal"]},
      # expected:
      seq: [">Create", :a, :b, ">c", :c, :d, :e],
      terminus: {seq: ["signal", :Create, :c]}

    assert_equal flow_options.to_h[:seq], ["flow_options", :Create, :c]
  end

  it "Conditions chain conditions, all conditions have to be met" do
    dispatcher_chain = Trailblazer::Circuit::WrapRuntime::Extension::Chain.new([my_extension])

    my_extension = Trailblazer::Circuit::WrapRuntime::Extension.new(
      Trailblazer::Circuit::WrapRuntime::Extension::Conditions.new(
        [
          ->(*, id) { id.is_a?(String) },
          ->(*, id) { id.to_s.downcase =~ /c/ }, # :Create, :c and "c|"
        ]
      ),
      dispatcher_chain
    )

    my_not_applied_extension = Trailblazer::Circuit::WrapRuntime::Extension.new(
      Trailblazer::Circuit::WrapRuntime::Extension::Conditions.new(
        [
          ->(*, id) { false },
        ]
      ),
      ->(*) { raise }
    )

    top_extension = Trailblazer::Circuit::WrapRuntime::Extension::Chain.new([my_not_applied_extension, my_extension])

    lib_ctx, flow_options, signal = assert_run my_pipe, :Create,
      flow_options: Trailblazer::Circuit::WrapRuntime::Runner.new(wrap_runtime: top_extension, seq: ["flow_options"]),
      signal:       {seq: ["signal"]},
      # expected:
      seq: [:a, :b, ">c|", :c, :d, :e],
      terminus: {seq: ["signal", "c|"]}
  end
end
