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











  class MyTrace
    class Capture < Struct.new(:captured_task, :position)
      def call(lib_ctx, flow_options, signal, target_ctx:, **)
        stack = flow_options.fetch(:stack)

        stack += [[position, captured_task, target_ctx.to_h.inspect]] # treat stack as an immutable object

        return lib_ctx, flow_options.merge(stack: stack), signal
      end
    end

    class Extension # TODO: name it Node::Extension?
      # Called through WrapRuntime::Runner.
      def self.call(*, id)
        [
          # those Adds instructions will use the builder for Resolver::Fixed.
          [:capture_before, Trailblazer::Circuit::Node[Capture.new(id, :before),  Trailblazer::Circuit::Task::Adapter::LibInterface, options: {already_wrapped: true}], :before, nil],
          [:capture_after,  Trailblazer::Circuit::Node[Capture.new(id, :after),   Trailblazer::Circuit::Task::Adapter::LibInterface, options: {already_wrapped: true}], :after, nil],
        ]
      end
    end
  end

  let(:lib) { Trailblazer::Circuit::Task::Adapter::LibInterface }

  it "we can extend with multiple extensions, eg NodeWrap and then tracing. this leverages Extension::Chain" do
    # TODO: extensions after it can see :node, eg.
    my_adds_producer = ->(*, id) do
      [
        [
          :capture_before,
          Trailblazer::Circuit::Node[T.def_task(:"before-#{id.to_sym}", success_signal: nil), Trailblazer::Circuit::Task::Adapter::LibInterface,
            options: {already_wrapped: true}],
          :before, :"task_wrap.call_task"
        ],
      ]
    end

    tw_trace_extension = Trailblazer::Circuit::WrapRuntime::Extension(
      ->(*, node, _) { node.options[:wrap_node] },
      adds_producer: my_adds_producer
    )

    node_wrap_extension = Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::EXTENSION

    dispatcher_chain = Trailblazer::Circuit::WrapRuntime::Extension::Chain.new([node_wrap_extension, tw_trace_extension])

    assert_run nil, :Create, node: my_create_node,
      seq: [:"before-Create", :"before-task_wrap.call_task", :"before-model", :"before-variable_mapping.in", :in, :"before-task_wrap.call_task", :model, :"before-variable_mapping.out", :out, :"before-save", :"before-task_wrap.call_task", :save],
      flow_options: Trailblazer::Circuit::WrapRuntime::Runner.new(wrap_runtime: dispatcher_chain)
  end

  it "we can do both of the above?" do

  end

  # this tests changing canonical variables {:circuit_options} like {:id} and {:node}.
  it "the Extension#call method can see all positionals and change them" do # DISCUSS: do we need an explicit test for changing and returning :node etc?
    my_tested_extension = ->(*args, id) do

      return *args, circuit_options.merge(
        id: id,
        id => {id: id, **circuit_options}
      )
    end

    my_capture = ->(_task, lib_ctx, flow_options, signal) do
      lib_ctx[:capture] << circuit_options

      return lib_ctx, flow_options, signal
    end

    my_pipeline = Trailblazer::Circuit::Builder.Pipeline(
      [:a, node: my_a_node = Trailblazer::Circuit::Node[nil, my_capture]],
      [:b, node: my_b_node = Trailblazer::Circuit::Node[nil, my_capture]],
    )

    my_top_node = Trailblazer::Circuit::Node[my_pipeline, Trailblazer::Circuit::Processor]

    lib_ctx, flow_options, signal = assert_run node: my_top_node,
      circuit_options: {
        runner: runner = Trailblazer::Circuit::WrapRuntime::Runner,
        id: :Create,
        wrap_runtime: my_tested_extension,
      },
      capture: [],
      seq: []

    my_generic_options = {context_implementation: Trailblazer::Circuit::Context, runner: runner}

    my_create_circuit_options = {**my_generic_options, id: :Create, node: my_top_node}

    assert_equal lib_ctx[:capture].size, 2
    assert_equal lib_ctx[:capture][0][:a], {**my_generic_options, id: :a, node: my_a_node, Create: my_create_circuit_options} # in :a, we can see :Create.
    assert_equal lib_ctx[:capture][1][:b], {**my_generic_options, id: :b, node: my_b_node, Create: my_create_circuit_options} # in :b, we can see :Create but not :a.
    assert_equal lib_ctx[:capture][0][:b], nil
    assert_equal lib_ctx[:capture][1][:a], nil

    assert_equal lib_ctx[:capture][1].slice(:id), {id: :b}
  end

  it "instead of applying some ADDS, the Extension builder can also return another :node altogether, and :id" do
    my_tested_extension_callable = ->(*args, node, id) do
      new_id = :"#{id}_#{node.task.object_id}"

      new_pipe = Trailblazer::Circuit::Builder.Pipeline(
        [new_id, T.def_tasks(new_id, success_signal: nil).method(new_id)],
        ["#{id} in pipe", node: node],
      )
      new_node = Trailblazer::Circuit::Node[new_pipe, Trailblazer::Circuit::Processor]

      return *args, new_node, new_id
    end

    my_tested_extension = Trailblazer::Circuit::WrapRuntime::Extension.new(
      ->(*, id) { [:Create, :a].include?(id) ? my_tested_extension : nil }, # DISCUSS: do we need that?
      my_tested_extension_callable
    )

    my_exec_context = T.def_tasks(:a, :b, success_signal: nil)

    my_a_pipeline = Trailblazer::Circuit::Builder.Pipeline(
      [:a_task, node: my_a_node = Trailblazer::Circuit::Node[my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface]]
    )

    my_pipeline = Trailblazer::Circuit::Builder.Pipeline(
      [:a, node: my_a_pipe_node = Trailblazer::Circuit::Node[my_a_pipeline, Trailblazer::Circuit::Processor]],
    )

    my_top_node = Trailblazer::Circuit::Node[my_pipeline, Trailblazer::Circuit::Processor]

    assert_run nil, :Create, node: my_top_node,
      flow_options: Trailblazer::Circuit::WrapRuntime::Runner.new(wrap_runtime: my_tested_extension),
      seq: [:"Create_#{my_pipeline.object_id}", :"a_#{my_a_pipeline.object_id}", :a]
  end

  # TODO: this should sit in the extensions_test.
  it "the Extension::Adds builder sees circuit_options" do
    # We record the passed {circuit_options}.
    my_tested_extension = Trailblazer::Circuit::WrapRuntime.Extension(
      ->(*, id:, **) { [:Create, :a].include?(id) },
      adds_producer: ->(*, **circuit_options) do
        my_tw_extension  = Struct.new(:options) do
          def call(lib_ctx, *args)
            lib_ctx[:capture] << options

            return lib_ctx, *args
          end
        end

        [
          [
            "capture for #{circuit_options[:id]}", Trailblazer::Circuit::Node[my_tw_extension.new(circuit_options), Trailblazer::Circuit::Task::Adapter::LibInterface],
            :before, nil
          ]
        ]
      end
    )

    my_exec_context = T.def_tasks(:a, :b, success_signal: nil)

    my_a_pipeline = Trailblazer::Circuit::Builder.Pipeline(
      [:a_task, node: my_a_node = Trailblazer::Circuit::Node[my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface]]
    )

    my_pipeline = Trailblazer::Circuit::Builder.Pipeline(
      [:a, node: my_a_pipe_node = Trailblazer::Circuit::Node[my_a_pipeline, Trailblazer::Circuit::Processor]],
    )

    my_top_node = Trailblazer::Circuit::Node[my_pipeline, Trailblazer::Circuit::Processor]

    lib_ctx, flow_options, signal = assert_run node: my_top_node,
      circuit_options: {
        runner: runner = Trailblazer::Circuit::WrapRuntime::Runner,
        id: :Create,
        wrap_runtime: my_tested_extension,
      },
      capture: [],
      seq: [:a]

    my_generic_options = {context_implementation: Trailblazer::Circuit::Context, runner: runner}

    assert_equal lib_ctx[:capture].size, 2
    assert_equal lib_ctx[:capture][0], {**my_generic_options, id: :Create, node: my_top_node}
    assert_equal lib_ctx[:capture][1], {**my_generic_options, id: :a, node: my_a_pipe_node}
  end

  it "wrap_runtime can implement tracing" do
    # ctx = {params: {song: nil}, slug: 666}

    # DISCUSS: how to merge multiple runtime extensions? canonical invoke!
    my_tracing_ext = Trailblazer::Circuit::WrapRuntime.Extension(
      ->(*, node, _) { node.to_h[:options][:traceable] },
      adds_producer: MyTrace::Extension
    )

     my_create_node, create_instance = Create_fixture()

    _, flow_options = assert_run nil, :Create, node: my_create_node, terminus: "Success",
      exec_context: create_instance,
      target_ctx: {params: {id: 1, title: "Uwe"}},
      flow_options: Trailblazer::Circuit::WrapRuntime::Runner.new(
        wrap_runtime: my_tracing_ext,
        stack: [].freeze
      ),
      expected_target_variables: {:params=>{:id=>1, title: "Uwe", :model=>Record.new(1, "Uwe")}}

    # pp flow_options[:stack]

    assert_stack flow_options[:stack], [
     [:before, :Create, {params: {id: 1, title: "Uwe"}}.inspect], # this is the Create.tw pipe
     [:before, :Model, {params: {id: 1, title: "Uwe"}}.inspect],
     [:before, :call_task, {id: 1, title: "Uwe"}.inspect],
     [:after, :call_task, {id: 1, title: "Uwe", model: Record.new(1)}.inspect],
     [:after, :Model, {params: {id: 1, title: "Uwe", model: Record.new(1)}}.inspect],
     [:before, :Save, {params: {id: 1, title: "Uwe", model: Record.new(1)}}.inspect],
     [:after, :Save, {params: {id: 1, title: "Uwe", model: Record.new(1, "Uwe")}}.inspect],
     [:before, :success, {params: {id: 1, title: "Uwe", model: Record.new(1, "Uwe")}}.inspect],
     [:after, :success, {params: {id: 1, title: "Uwe", model: Record.new(1, "Uwe")}}.inspect],
     [:after, :Create, {params: {id: 1, title: "Uwe", model: Record.new(1, "Uwe")}}.inspect]]
  end
end

class MyRunnerWithExtraNodeTest < Minitest::Spec
  let(:my_extensions) do
    # DISCUSS: how to merge multiple runtime extensions? canonical invoke!
    my_tracing_ext = Trailblazer::Circuit::WrapRuntime.Extension(adds_producer: WrapRuntimeTest::MyTrace::Extension)

    my_extensions = Trailblazer::Circuit::WrapRuntime::Extension::Set.new(
      [
        Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap,
        my_tracing_ext,
      ]
    )
  end

  def _Id(id, wrapped_node)
    Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Id.new(id, wrapped_node)
  end

  it "test Id() that we have access to the {wrapped_node}" do
    skip "test that!"
  end

  it "We can chain conditions and extensions" do
    # what we currently do here: node-wrap only {:trace_me} nodes, then apply capture steps to the wrap_node.
    # since we apply capture directly after the node-wrap, we know we're in a wrap_node and don't need to check any condition for tracing.
    # that means: we need {NodeWrap::CONDITION + :trace_me} and then, run both extensions, NodeWrap and Trace


    my_wrap_and_trace_extension = Trailblazer::Circuit::WrapRuntime::Extension.new(
      # conditions:
      Trailblazer::Circuit::WrapRuntime::Extension::Conditions.new(
        [
          ->(*, node:, **) { node.options[:trace_me] },
          Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::CONDITION
        ]
      ),
      # extension chain:
      Trailblazer::Circuit::WrapRuntime::Extension::Chain.new(
        [
          Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::EXTENSION,
          Trailblazer::Circuit::WrapRuntime::Extension::AddsInstructions.new(WrapRuntimeTest::MyTrace::Extension)
        ]
      )
    )

    my_b_node = Trailblazer::Circuit::Node[T.def_task(:b, success_signal: "Right"), Trailblazer::Circuit::Task::Adapter::LibInterface,
      options: {trace_me: true}
    ]

    my_top_node = Trailblazer::Circuit::Builder.Pipeline(
      [:a, T.def_tasks(:a, success_signal: "Right").method(:a)], # no tracing.
      [:b, node: my_b_node],
      [:c, T.def_tasks(:c, success_signal: "Right").method(:c)], # no tracing.
    )
    my_top_node = Trailblazer::Circuit::Node[my_top_node, Trailblazer::Circuit::Processor, options: {trace_me: true}]

    runner = Trailblazer::Circuit::WrapRuntime::Runner

    lib_ctx, flow_options, signal = runner.(
      {target_ctx: {seq: []}},
      {stack: [].freeze,},
      nil,
      runner: runner,
      wrap_runtime: my_wrap_and_trace_extension,
      context_implementation: Trailblazer::Circuit::Context,
      id: :my_top_node,
      node: my_top_node,
    )

    assert_equal signal, "Right"
    assert_equal lib_ctx[:target_ctx][:seq], [:a, :b, :c]
    # pp flow_options[:stack]

    # it only traces top and b.
    assert_equal flow_options[:stack],
      [[:before, _Id(:my_top_node, my_top_node), "{}"],
       [:before, _Id(:b, my_b_node), "{}"],
       [:after, _Id(:b, my_b_node), "{}"],
       [:after, _Id(:my_top_node, my_top_node), "{}"]]
  end
end

