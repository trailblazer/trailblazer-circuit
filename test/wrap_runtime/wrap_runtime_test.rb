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
      [:Model, model_tw, Trailblazer::Circuit::Processor, connections: {Right => [:Save, Right], Left => [:failure, Left]}, options: {traceable: true, task_wrap: true}],
      # [:Validate, validate_circuit, Trailblazer::Circuit::Processor], connections: {Right => :Validate, Left => :failure}]
      [:Save, save_tw, Trailblazer::Circuit::Processor, connections: {Right => [:success, Right], Left => [:failure, Left]}, options: {traceable: true, task_wrap: true}],
      [:success, success_pipe, Trailblazer::Circuit::Processor, connections: {:Success => [nil, :Success]}, options: {traceable: true, task_wrap: true}],
      [:failure, failure_pipe, Trailblazer::Circuit::Processor, connections: {:Failure => [nil, :Failure]}, options: {traceable: true, task_wrap: true}]
    )

    create_tw = Trailblazer::Circuit::Builder.Pipeline(
      [:call_task, create_circuit, Trailblazer::Circuit::Processor]
    )

    canonical_node = Trailblazer::Circuit::Node[create_tw, Trailblazer::Circuit::Processor, options: {traceable: true, task_wrap: true}]

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

        stack += [[position, captured_task, flow_options[:application_ctx].to_h.inspect]] # treat stack as an immutable object

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

  let(:lib) { Trailblazer::Circuit::Task::Adapter::LibInterface }

  let(:my_create_node) do
    my_exec_context = T.def_tasks(:in, :model, :out, :save, success_signal: nil, passthrough_signal: true)

    my_model_tw = Trailblazer::Circuit::Builder.Pipeline(
      [:"variable_mapping.in", my_exec_context.method(:in)],
      [:"task_wrap.call_task", my_exec_context.method(:model)],
      [:"variable_mapping.out", my_exec_context.method(:out)],
    )

    my_save_tw = Trailblazer::Circuit::Builder.Pipeline(
      [:"task_wrap.call_task", my_exec_context.method(:save)]
    )

    my_create = Trailblazer::Circuit::Builder.Pipeline(
      [:model, my_model_tw, Trailblazer::Circuit::Processor, options: {task_wrap: true}],
      [:save, my_save_tw, Trailblazer::Circuit::Processor, options: {task_wrap: true}],
    )

    my_canonical_tw = Trailblazer::Circuit::Builder.Pipeline(
      [:"task_wrap.call_task", my_create, Trailblazer::Circuit::Processor]
    )

    my_canonical_node = Trailblazer::Circuit::Node[my_canonical_tw, Trailblazer::Circuit::Processor, options: {task_wrap: true}]
  end

  it "testing the {my_create_tw} fixture" do
    assert_run my_create_node, node: true, seq: [:in, :model, :out, :save]#, terminus: "Right"
  end

  it "test condition/order: we can simply add steps to a task_wrap pipeline via {:wrap_runtime}" do
    my_adds_producer = ->(id:, **) do
      [
        [:capture_before, Trailblazer::Circuit::Node[T.def_task(:"before-#{id}", success_signal: nil), Trailblazer::Circuit::Task::Adapter::LibInterface, options: {already_wrapped: true}], :before, :"task_wrap.call_task"],
      ]
    end

    tw_trace_extension = Trailblazer::Circuit::WrapRuntime::Extension(
      ->(*, node:, **) { node.options[:task_wrap] },
      adds: my_adds_producer
    )

    # dispatcher_chain = Trailblazer::Circuit::WrapRuntime::Extension::Chain.new([tw_trace_extension])
    # Test that we can use a plain Extension instead of Extension::Chain.
    assert_run my_create_node, seq: [:"before-Create", :in, :"before-model", :model, :out, :"before-save", :save],
      node: true,
      circuit_options: {
        runner: runner = Trailblazer::Circuit::WrapRuntime::Runner,
        id: :Create,
        wrap_runtime: tw_trace_extension,
      }
  end

  it "a basic Extension can see {lib_ctx, flow_options, signal, **circuit_options}" do
    # In this example, I implement a mini-tracing extension that only traces "before" as an Extension
    # is invoked before the actual node is run.
    #
    # The extension is a simple callable that doesn't involve any Decider, Chain or whatever.
    #
    # We record all incoming arguments in {signal} and pass it on.
    my_basic_extension = ->(lib_ctx, flow_options, signal, **circuit_options) do
      signal += [[circuit_options[:id], lib_ctx.inspect, flow_options.dup, circuit_options.dup]]

      return lib_ctx, flow_options, signal, circuit_options # we can return {circuit_options}.
    end

    my_create_node = self.my_create_node

    circuit_options = {
      runner: runner = Trailblazer::Circuit::WrapRuntime::Runner,
      id: :Create,
      wrap_runtime: ->(*args, **circuit_options) { my_basic_extension.(*args, **circuit_options) },
    }

    lib_ctx, flow_options, signal = Trailblazer::Circuit::WrapRuntime::Runner.(
      {target_ctx: {seq: []}},
      {},
      [], # signal acts as a "stack".
      **circuit_options.merge(node: my_create_node, id: :Create)
    )

    assert_equal lib_ctx, {target_ctx: {seq: [:in, :model, :out, :save]}}

    expected_circuit_options = circuit_options.clone
    expected_circuit_options.delete(:wrap_runtime) # we don't see {:wrap_runtime}.

    # Let's check what each Extension sees as incoming args.
    assert_equal signal[0], [
      :Create, # this is the taskWrap.
      {target_ctx: {seq: []}}.inspect,
      {},
      expected_circuit_options.merge(id: :Create, node: my_create_node)
    ]

    # this is actually the Create circuit,
    assert_equal signal[1], [
      :"task_wrap.call_task",
      {target_ctx: {seq: []}}.inspect,
      {},
      expected_circuit_options.merge(id: :"task_wrap.call_task", node: my_create_node.task.nodes[:"task_wrap.call_task"])
    ]

    # this is model's taskWrap.
    assert_equal signal[2], [
      :model,
      {target_ctx: {seq: []}}.inspect,
      {},
      expected_circuit_options.merge(id: :model, node: my_create_node.task.nodes[:"task_wrap.call_task"].task.nodes[:model])
    ]

    # this is :in in model's taskWrap..
    assert_equal signal[3], [
      :"variable_mapping.in",
      {target_ctx: {seq: []}}.inspect,
      {},
      expected_circuit_options.merge(id: :"variable_mapping.in", node: my_create_node.task.nodes[:"task_wrap.call_task"].task.nodes[:model].task.nodes[:"variable_mapping.in"])
    ]

    # this is the actual {#model} method,
    assert_equal signal[4], [
      :"task_wrap.call_task",
      {target_ctx: {seq: [:in]}}.inspect,
      {},
      expected_circuit_options.merge(id: :"task_wrap.call_task", node: my_create_node.task.nodes[:"task_wrap.call_task"].task.nodes[:model].task.nodes[:"task_wrap.call_task"])
    ]

    # this is :out in model's taskWrap..
    assert_equal signal[5], [
      :"variable_mapping.out",
      {target_ctx: {seq: [:in, :model]}}.inspect,
      {},
      expected_circuit_options.merge(id: :"variable_mapping.out", node: my_create_node.task.nodes[:"task_wrap.call_task"].task.nodes[:model].task.nodes[:"variable_mapping.out"])
    ]

    # this is {:save} taskWrap.
    assert_equal signal[6], [
      :save,
      {target_ctx: {seq: [:in, :model, :out]}}.inspect,
      {},
      expected_circuit_options.merge(id: :save, node: my_create_node.task.nodes[:"task_wrap.call_task"].task.nodes[:save])
    ]

    # this is the actual {#save} method,
    assert_equal signal[7], [
      :"task_wrap.call_task",
      {target_ctx: {seq: [:in, :model, :out]}}.inspect,
      {},
      expected_circuit_options.merge(id: :"task_wrap.call_task", node: my_create_node.task.nodes[:"task_wrap.call_task"].task.nodes[:save].task.nodes[:"task_wrap.call_task"])
    ]

    assert_nil signal[8]
  end

  it "a basic Extension can change lib_ctx, flow_options, and circuit_options" do
    # TODO: add test that really captures all circuit_options so we can test what we see on each level?

    my_basic_extension = ->(lib_ctx, flow_options, signal, **circuit_options) do
      lib_ctx = lib_ctx.merge(lib_ctx_stack: lib_ctx[:lib_ctx_stack] + [circuit_options[:id]])
      flow_options = flow_options.merge(flow_options_stack: flow_options[:flow_options_stack] + [circuit_options[:id]])
      circuit_options = circuit_options.merge(circuit_options_stack: circuit_options[:circuit_options_stack] + [circuit_options[:id]])

      return lib_ctx, flow_options, signal, circuit_options # we can return {circuit_options}.
    end

    my_create_node = self.my_create_node

    my_capture_adapter = ->(_, lib_ctx, *args, **circuit_options) {
      lib_ctx = lib_ctx.merge(captured_circuit_options: circuit_options.dup)

      return lib_ctx, *args
    }

    my_create_node = Trailblazer::Circuit::Node::Patch.(
      my_create_node,
      [:"task_wrap.call_task"],
      adds: [
        [
          :my_capture,
          Trailblazer::Circuit::Node[nil, my_capture_adapter],
          :after
        ]
      ]
    )

    circuit_options = {
      runner: runner = Trailblazer::Circuit::WrapRuntime::Runner,
      id: :Create,
      wrap_runtime: ->(*args, **circuit_options) { my_basic_extension.(*args, **circuit_options) },
    }

    lib_ctx, flow_options, signal = Trailblazer::Circuit::WrapRuntime::Runner.(
      {target_ctx: {seq: []}, lib_ctx_stack: []},
      {flow_options_stack: []},
      [], # signal acts as a "stack".
      **circuit_options.merge(node: my_create_node, id: :Create, circuit_options_stack: [])
    )

    expected_circuit_options = {
      **circuit_options,
      id: :my_capture,
      node: my_create_node.task.nodes[:"task_wrap.call_task"].task.nodes[:my_capture],
      :circuit_options_stack=>[:Create, :"task_wrap.call_task", :my_capture] # we only see the Create/task_wrap level, not anything from siblings.
    }

    assert_equal lib_ctx, {
      target_ctx: {seq: [:in, :model, :out, :save]},
      :lib_ctx_stack=>[:Create, :"task_wrap.call_task", :model, :"variable_mapping.in", :"task_wrap.call_task", :"variable_mapping.out", :save, :"task_wrap.call_task", :my_capture],
      :captured_circuit_options => expected_circuit_options,
    }
    assert_equal flow_options, {:flow_options_stack=>[:Create, :"task_wrap.call_task", :model, :"variable_mapping.in", :"task_wrap.call_task", :"variable_mapping.out", :save, :"task_wrap.call_task", :my_capture]}
  end

  it "we can extend with multiple extensions, eg NodeWrap and then tracing. this leverages Extension::Chain" do
    # TODO: extensions after it can see :node, eg.
    my_adds_producer = ->(*, id:, **) do
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
      ->(*, node:, **) { node.options[:wrap_node] },
      adds: my_adds_producer
    )

    node_wrap_extension = Trailblazer::Circuit::WrapRuntime::Extension::NodeWrap::EXTENSION

    dispatcher_chain = Trailblazer::Circuit::WrapRuntime::Extension::Chain.new([node_wrap_extension, tw_trace_extension])

    assert_run my_create_node, seq: [:"before-Create", :"before-task_wrap.call_task", :"before-model", :"before-variable_mapping.in", :in, :"before-task_wrap.call_task", :model, :"before-variable_mapping.out", :out, :"before-save", :"before-task_wrap.call_task", :save],
      node: true,
      circuit_options: {
        runner: runner = Trailblazer::Circuit::WrapRuntime::Runner,
        id: :Create,
        wrap_runtime: dispatcher_chain,
      }
  end

  it "we can do both of the above?" do

  end

  # this tests changing canonical variables {:circuit_options} like {:id} and {:node}.
  it "the Extension#call method can see all positionals and {circuit_options}, and change them" do # DISCUSS: do we need an explicit test for changing and returning :node etc?
    my_tested_extension = ->(*args, id:, **circuit_options) do

      return *args, circuit_options.merge(
        id: id,
        id => {id: id, **circuit_options}
      )
    end

    my_capture = ->(_task, lib_ctx, flow_options, signal, **circuit_options) do
      lib_ctx[:capture] << circuit_options

      return lib_ctx, flow_options, signal
    end

    my_pipeline = Trailblazer::Circuit::Builder.Pipeline(
      [:a, node: my_a_node = Trailblazer::Circuit::Node[nil, my_capture]],
      [:b, node: my_b_node = Trailblazer::Circuit::Node[nil, my_capture]],
    )

    my_top_node = Trailblazer::Circuit::Node[my_pipeline, Trailblazer::Circuit::Processor]

    lib_ctx, flow_options, signal = assert_run my_top_node, node: true,
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
    my_tested_extension_callable = ->(*args, id:, node:, **circuit_options) do
      new_id = :"#{id}_#{node.task.object_id}"

      new_pipe = Trailblazer::Circuit::Builder.Pipeline(
        [new_id, T.def_tasks(new_id, success_signal: nil).method(new_id)],
        ["#{id} in pipe", node: node],
      )
      new_node = Trailblazer::Circuit::Node[new_pipe, Trailblazer::Circuit::Processor]

      return *args, circuit_options.merge(node: new_node, id: new_id)
    end

    my_tested_extension = Trailblazer::Circuit::WrapRuntime::Extension.new(
      ->(*, id:, **) { [:Create, :a].include?(id) ? my_tested_extension : nil }, # DISCUSS: do we need that?
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

    lib_ctx, flow_options, signal = assert_run my_top_node, node: true,
      circuit_options: {
        runner: runner = Trailblazer::Circuit::WrapRuntime::Runner,
        id: :Create,
        wrap_runtime: my_tested_extension,
      },
      seq: [:"Create_#{my_pipeline.object_id}", :"a_#{my_a_pipeline.object_id}", :a]
  end

  # TODO: this should sit in the extensions_test.
  it "the Extension::Adds builder sees circuit_options" do
    # We record the passed {circuit_options}.
    my_tested_extension = Trailblazer::Circuit::WrapRuntime.Extension(
      ->(*, id:, **) { [:Create, :a].include?(id) },
      adds: ->(*, **circuit_options) do
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

    lib_ctx, flow_options, signal = assert_run my_top_node, node: true,
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
    ctx = {params: {song: nil}, slug: 666}

    # DISCUSS: how to merge multiple runtime extensions? canonical invoke!
    my_tracing_ext = Trailblazer::Circuit::WrapRuntime.Extension(
      ->(*, node:, **) { node.to_h[:options][:traceable] },
      adds: MyTrace::Extension
    )

     my_create_node, create_instance = Create_fixture()

    lib_ctx, flow_options, signal = Trailblazer::Circuit::WrapRuntime::Runner.(
      {},
      {
        application_ctx: {params: {id: 1, title: "Uwe"}},
        stack: [].freeze,
      },
      nil,
      runner: Trailblazer::Circuit::WrapRuntime::Runner,
      # wrap_runtime: Hash.new(my_extensions),
      wrap_runtime: my_tracing_ext,
      context_implementation: Trailblazer::Circuit::Context,
      exec_context: create_instance,
      id: :Create,
      node: my_create_node,
    )

    assert_equal signal, :Success
    assert_equal flow_options[:application_ctx], {:params=>{:id=>1, title: "Uwe", :model=>Record.new(1, "Uwe")}}

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
    my_tracing_ext = Trailblazer::Circuit::WrapRuntime.Extension(adds: WrapRuntimeTest::MyTrace::Extension)

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

