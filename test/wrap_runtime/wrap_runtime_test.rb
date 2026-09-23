require "test_helper"

# FIXME: add test for a non Node node :D
# add test for specific tasks

class WrapRuntimeTest < Minitest::Spec
  def assert_stack(actual, expected)
    assert_equal actual.size, expected.size

    actual.each_with_index do |capture, i|
      assert_equal capture, expected[i], "index #{i} mismatch"
    end
  end

  Record = Struct.new(:id, :title)
  def Create_fixture
    my_io = Class.new do
      def self.model_input(lib_ctx, flow_options, signal, **)
        lib_ctx[:original_application_ctx] = app_ctx = flow_options.fetch(:application_ctx)

        flow_options = flow_options.merge(application_ctx: app_ctx.fetch(:params)) # "effective" ctx

        return lib_ctx, flow_options, signal
      end

      def self.model_output(lib_ctx, flow_options, signal, **)
        flow_options = flow_options.merge(application_ctx: lib_ctx[:original_application_ctx])

        return lib_ctx, flow_options, signal
      end
    end

    my_activity = Class.new do
      def compute_signal(lib_ctx, flow_options, signal, **)
        return lib_ctx, flow_options, Right
      end

      def success(lib_ctx, flow_options, signal, **)
        return lib_ctx, flow_options, :Success
      end

      def failure(lib_ctx, flow_options, signal, **)
        return lib_ctx, flow_options, :Failure
      end
    end.new

    create_instance = Class.new do
      def find(lib_ctx, flow_options, signal, **)
        id = flow_options[:application_ctx][:id]

        flow_options[:application_ctx][:model] = Record.new(id)

        return lib_ctx, flow_options, signal
      end

      def save(lib_ctx, flow_options, signal, **)
        params = flow_options[:application_ctx][:params]

        params[:model].title = params[:title]

        return lib_ctx, flow_options, signal
      end
    end.new

    model_call_pipe = Trailblazer::Circuit::Builder.Pipeline(
      [:find, :find, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      [:compute_signal, my_activity.method(:compute_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
    )

    model_tw = Trailblazer::Circuit::Builder.Pipeline(
      [:input, my_io.method(:model_input), Trailblazer::Circuit::Task::Adapter::LibInterface],
      [:call_task, model_call_pipe, Trailblazer::Circuit::Processor, options: {traceable: true}],
      [:output, my_io.method(:model_output), Trailblazer::Circuit::Task::Adapter::LibInterface],
    )

    save_tw = Trailblazer::Circuit::Builder.Pipeline(
      # [:input, my_io.method(:model_input), Trailblazer::Circuit::Task::Adapter::LibInterface],
      [:call_task, :save , Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      [:compute_signal, my_activity.method(:compute_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
      # [:output, my_io.method(:model_output), Trailblazer::Circuit::Task::Adapter::LibInterface],
    )

    success_pipe = Trailblazer::Circuit::Builder::Pipeline(
      [:call_task, my_activity.method(:success), Trailblazer::Circuit::Task::Adapter::LibInterface],
    )

    failure_pipe = Trailblazer::Circuit::Builder::Pipeline(
      [:call_task, my_activity.method(:failure), Trailblazer::Circuit::Task::Adapter::LibInterface],
    )

    create_circuit, _ = Trailblazer::Circuit::Builder.Circuit(
      [:Model, model_tw, Trailblazer::Circuit::Processor, connections: {Right => [:Save, Right], Left => [:failure, Left]}, options: {traceable: true}],
      # [:Validate, validate_circuit, Trailblazer::Circuit::Processor], connections: {Right => :Validate, Left => :failure}]
      [:Save, save_tw, Trailblazer::Circuit::Processor, connections: {Right => [:success, Right], Left => [:failure, Left]}, options: {traceable: true}],
      [:success, success_pipe, Trailblazer::Circuit::Processor, connections: {:Success => [nil, :Success]}, options: {traceable: true}],
      [:failure, failure_pipe, Trailblazer::Circuit::Processor, connections: {:Failure => [nil, :Failure]}, options: {traceable: true}]
    )

    create_tw = Trailblazer::Circuit::Builder.Pipeline(
      [:call_task, create_circuit, Trailblazer::Circuit::Processor]
    )

    canonical_node = Trailblazer::Circuit::Node[create_tw, Trailblazer::Circuit::Processor, options: {traceable: true}]

    return canonical_node, create_instance
  end

  it "test Create fixture" do
    my_create_node, create_instance = Create_fixture()

    lib_ctx, flow_options, signal = Trailblazer::Circuit::Node::Runner.(
      {},
      {
        application_ctx: {params: {id: 1, title: "Rancid"}},
      },
      nil,
      runner: Trailblazer::Circuit::Node::Runner,
      context_implementation: Trailblazer::Circuit::Context,
      exec_context: create_instance,
      node: my_create_node,
    )

    assert_equal signal, :Success
    assert_equal flow_options[:application_ctx], {:params=>{:id=>1, title: "Rancid", :model=>Record.new(1, "Rancid")}}
  end

  class MyTrace
    class Capture < Struct.new(:captured_task, :position)
      def call(lib_ctx, flow_options, signal, **) # FIXME: we need circuit_options for the {:task}.
        stack = flow_options.fetch(:stack)

        stack += [[position, captured_task, CU.inspect(flow_options[:application_ctx].to_h)]] # treat stack as an immutable object

        return lib_ctx, flow_options.merge(stack: stack), signal
      end
    end

    class Extension # TODO: name it Node::Extension?
      # Called through WrapRuntime::Runner.
      def self.call(id:, **attrs)
        [
          # those Adds instructions will use the builder for Resolver::Fixed.
          [:capture_before, Trailblazer::Circuit::Node[Capture.new(id, :before),  Trailblazer::Circuit::Task::Adapter::LibInterface, options: {already_wrapped: true}], :before, nil],
          [:capture_after,  Trailblazer::Circuit::Node[Capture.new(id, :after),   Trailblazer::Circuit::Task::Adapter::LibInterface, options: {already_wrapped: true}], :after, nil],
        ]
      end
    end
  end

  it "the {:wrap_runtime} resolver can access {:id}" do
    raise
  end

  it "wrap_runtime can implement tracing" do
    ctx = {params: {song: nil}, slug: 666}

    # DISCUSS: how to merge multiple runtime extensions? canonical invoke!
    my_tracing_ext = Trailblazer::Circuit::WrapRuntime.Extension(adds: MyTrace::Extension)

    my_extensions = Trailblazer::Circuit::WrapRuntime::Extension::Set.new(
      [
        my_tracing_ext
      ]
    )

    my_create_node, create_instance = Create_fixture()

    # FIXME: make this canonical.
    my_wrap_runtime_resolver = Struct.new(:default_extension_set) do
      def [](node:, **circuit_options)
        # {:traceable} marks pipes, basically, which we can extend with capture steps.
        if node.to_h[:options][:traceable]
          return default_extension_set
        end
      end
    end.new(my_extensions)

    lib_ctx, flow_options, signal = Trailblazer::Circuit::WrapRuntime::Runner.(
      {},
      {
        application_ctx: {params: {id: 1, title: "Uwe"}},
        stack: [].freeze,
      },
      nil,
      runner: Trailblazer::Circuit::WrapRuntime::Runner,
      # wrap_runtime: Hash.new(my_extensions),
      wrap_runtime: my_wrap_runtime_resolver,
      context_implementation: Trailblazer::Circuit::Context,
      exec_context: create_instance,
      id: :Create,
      node: my_create_node,
    )

    assert_equal signal, :Success
    assert_equal flow_options[:application_ctx], {:params=>{:id=>1, title: "Uwe", :model=>Record.new(1, "Uwe")}}

    # pp flow_options[:stack]

    assert_stack flow_options[:stack], [
     [:before, :Create, "{:params=>{:id=>1, :title=>\"Uwe\"}}"], # this is the Create.tw pipe
     [:before, :Model, "{:params=>{:id=>1, :title=>\"Uwe\"}}"],
     [:before, :call_task, "{:id=>1, :title=>\"Uwe\"}"],
     [:after, :call_task, "{:id=>1, :title=>\"Uwe\", :model=>#<struct WrapRuntimeTest::Record id=1, title=nil>}"],
     [:after, :Model, "{:params=>{:id=>1, :title=>\"Uwe\", :model=>#<struct WrapRuntimeTest::Record id=1, title=nil>}}"],
     [:before, :Save, "{:params=>{:id=>1, :title=>\"Uwe\", :model=>#<struct WrapRuntimeTest::Record id=1, title=nil>}}"],
     [:after, :Save, "{:params=>{:id=>1, :title=>\"Uwe\", :model=>#<struct WrapRuntimeTest::Record id=1, title=\"Uwe\">}}"],
     [:before, :success, "{:params=>{:id=>1, :title=>\"Uwe\", :model=>#<struct WrapRuntimeTest::Record id=1, title=\"Uwe\">}}"],
     [:after, :success, "{:params=>{:id=>1, :title=>\"Uwe\", :model=>#<struct WrapRuntimeTest::Record id=1, title=\"Uwe\">}}"],
     [:after, :Create, "{:params=>{:id=>1, :title=>\"Uwe\", :model=>#<struct WrapRuntimeTest::Record id=1, title=\"Uwe\">}}"]]
  end
end

class MyRunnerWithExtraNodeTest < Minitest::Spec
  let(:my_extensions) do
    # DISCUSS: how to merge multiple runtime extensions? canonical invoke!
    my_tracing_ext = Trailblazer::Circuit::WrapRuntime.Extension(adds: WrapRuntimeTest::MyTrace::Extension)

    my_extensions = Trailblazer::Circuit::WrapRuntime::Extension::Set.new(
      [
        Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap,
        my_tracing_ext,
      ]
    )
  end

  it "we can extend any kind of node by wrapping it in another mini Pipeline. using {Extension::NodeWrap}" do
    ctx = {params: {song: nil}, slug: 666}

    my_create_node, create_instance = WrapRuntimeTest.new(nil).Create_fixture()

    # This resolver is called for every node, whether that's a real one or a virtual.
    my_wrap_runtime_resolver = Trailblazer::Circuit::WrapRuntime::Extension::Resolver.new(default_extension_set: my_extensions, conditions: [Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Resolver::CONDITION])

    # DISCUSS: extension_set, resolver = WrapRuntime::Extension::NodeWrap() ???

    my_single_node_a = Trailblazer::Circuit::Node[T.def_tasks(:a, success_signal: "Right").method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface]
    my_single_node_b = Trailblazer::Circuit::Node[T.def_tasks(:b, success_signal: "Right").method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface]

    # trace single node
    # pp my_create_node
    runner = Trailblazer::Circuit::WrapRuntime::Runner

    lib_ctx, flow_options, signal = runner.(
      {target_ctx: {seq: []}},
      {stack: [].freeze,},
      nil,
      runner: runner,
      wrap_runtime: my_wrap_runtime_resolver,
      context_implementation: Trailblazer::Circuit::Context,
      id: :a,
      node: my_single_node_a,
    )

    pp flow_options
    assert_equal flow_options[:stack], [[:before, "...a", "{}"], [:after, "...a", "{}"]]
    assert_equal lib_ctx[:target_ctx][:seq], [:a]
# raise


    my_tw_for_a = Trailblazer::Circuit::Builder.Circuit(
      [:call_task_for_a, my_single_node_a]
    )
puts "TTTTTTTTTWWW"
    lib_ctx, flow_options, signal = runner.(
      {target_ctx: {seq: []}},
      {stack: [].freeze,},
      nil,
      runner: runner,
      wrap_runtime: my_wrap_runtime_resolver,
      context_implementation: Trailblazer::Circuit::Context,
      id: :tw_for_a,
      node: Trailblazer::Circuit::Node[my_tw_for_a, Trailblazer::Circuit::Processor],
    )

    assert_equal signal, "Right"
    assert_equal lib_ctx[:target_ctx][:seq], [:a]
    pp flow_options[:stack]

    my_tw_for_b = Trailblazer::Circuit::Builder.Circuit(
      [:b, node: my_single_node_b], # todo: should be call_task_for_b
      [:a, my_tw_for_a, Trailblazer::Circuit::Processor],
    )

puts "ab hiiier"
    lib_ctx, flow_options, signal = runner.(
      {target_ctx: {seq: []}},
      {stack: [].freeze,},
      nil,
      runner: runner,
      wrap_runtime: my_wrap_runtime_resolver,
      context_implementation: Trailblazer::Circuit::Context,
      id: :tw_for_b_and_a,
      node: Trailblazer::Circuit::Node[my_tw_for_b, Trailblazer::Circuit::Processor],
    )

    assert_equal signal, "Right"
    assert_equal lib_ctx[:target_ctx][:seq], [:b, :a]
    pp flow_options[:stack]

    assert_equal flow_options[:stack],
    [[:before, "...tw_for_b_and_a", "{}"],
     [:before, "...b", "{}"],
     [:after, "...b", "{}"],
     [:before, "...a", "{}"],
     [:before, "...call_task_for_a", "{}"],
     [:after, "...call_task_for_a", "{}"],
     [:after, "...a", "{}"],
     [:after, "...tw_for_b_and_a", "{}"]]
  end

  it "NodeWrap preserves the node's original options" do
    my_create_node, create_instance = WrapRuntimeTest.new(nil).Create_fixture()

    my_business_step_only_resolver = Trailblazer::Circuit::WrapRuntime::Extension::Resolver.new(default_extension_set: my_extensions,
      conditions: [
        Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::Resolver::CONDITION,
        ->(node:, **) { node.options[:trace_me] }
      ]
    )

    my_top_node = Trailblazer::Circuit::Builder.Pipeline(
      [:a, T.def_tasks(:a, success_signal: "Right").method(:a)],
      [:b, T.def_tasks(:b, success_signal: "Right").method(:b), options: {trace_me: true}],
      [:c, T.def_tasks(:c, success_signal: "Right").method(:c)],
    )
    my_top_node = Trailblazer::Circuit::Node[my_top_node, Trailblazer::Circuit::Processor, options: {trace_me: true}]

    runner = Trailblazer::Circuit::WrapRuntime::Runner

    lib_ctx, flow_options, signal = runner.(
      {target_ctx: {seq: []}},
      {stack: [].freeze,},
      nil,
      runner: runner,
      wrap_runtime: my_business_step_only_resolver,
      context_implementation: Trailblazer::Circuit::Context,
      id: :my_top_node,
      node: my_top_node,
    )

    assert_equal signal, "Right"
    assert_equal lib_ctx[:target_ctx][:seq], [:a, :b, :c]
    # pp flow_options[:stack]

    # it only traces top and b.
    assert_equal flow_options[:stack],
      [[:before, "...my_top_node", "{}"],
       [:before, "...b", "{}"],
       [:after, "...b", "{}"],
       [:after, "...my_top_node", "{}"]]
  end
end

