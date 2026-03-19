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
      def find(ctx, id:, **)
        ctx[:model] = Record.new(id)
      end

      def save(ctx, params:, **)
        params[:model].title = params[:title]
      end
    end.new

    model_call_pipe = Trailblazer::Circuit::Builder.Pipeline(
      [:find, :find, Trailblazer::Circuit::Task::Adapter::StepInterface::InstanceMethod],
      [:compute_signal, my_activity.method(:compute_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
    )

    model_tw = Trailblazer::Circuit::Builder.Pipeline(
      [:input, my_io.method(:model_input), Trailblazer::Circuit::Task::Adapter::LibInterface],
      [:call_task, model_call_pipe, Trailblazer::Circuit::Processor],
      [:output, my_io.method(:model_output), Trailblazer::Circuit::Task::Adapter::LibInterface],
    )

    save_tw = Trailblazer::Circuit::Builder.Pipeline(
      # [:input, my_io.method(:model_input), Trailblazer::Circuit::Task::Adapter::LibInterface],
      [:call_task, :save , Trailblazer::Circuit::Task::Adapter::StepInterface::InstanceMethod],
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
      [[:Model, model_tw, Trailblazer::Circuit::Processor], {Right => :Save, Left => :failure}],
      # [[:Validate, validate_circuit, Trailblazer::Circuit::Processor], {Right => :Validate, Left => :failure}]
      [[:Save, save_tw, Trailblazer::Circuit::Processor], {Right => :success, Left => :failure}],
      [[:success, success_pipe, Trailblazer::Circuit::Processor], {}],
      [[:failure, failure_pipe, Trailblazer::Circuit::Processor], {}],
      termini: [:success, :failure]
    )

    create_tw = Trailblazer::Circuit::Builder.Pipeline(
      [:call_task, create_circuit, Trailblazer::Circuit::Processor]
    )

    canonical_node = Trailblazer::Circuit::Node[:Create, create_tw, Trailblazer::Circuit::Processor]

    return canonical_node, create_instance
  end

  it "test Create fixture" do
    my_create_node, create_instance = Create_fixture()

    lib_ctx, flow_options, signal = Trailblazer::Circuit::Node::Runner.(
      my_create_node,
      {exec_context: create_instance},
      {
        application_ctx: {params: {id: 1, title: "Rancid"}},
      },
      nil,
      runner: Trailblazer::Circuit::Node::Runner,
      context_implementation: Trailblazer::Circuit::Context,
    )

    assert_equal signal, :Success
    assert_equal flow_options[:application_ctx], {:params=>{:id=>1, title: "Rancid", :model=>Record.new(1, "Rancid")}}
  end

  it "wrap_runtime can implement tracing" do
    ctx = {params: {song: nil}, slug: 666}

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
            [Trailblazer::Circuit::Node[:capture_before, Capture.new(id, :before),  Trailblazer::Circuit::Task::Adapter::LibInterface], :before],
            [Trailblazer::Circuit::Node[:capture_after,  Capture.new(id, :after),   Trailblazer::Circuit::Task::Adapter::LibInterface], :after],
          ]
        end
      end
    end


    # DISCUSS: how to merge multiple runtime extensions? canonical invoke!
    my_tracing_ext = Trailblazer::Circuit::WrapRuntime.Extension(adds: MyTrace::Extension)

    my_extensions = Trailblazer::Circuit::WrapRuntime::Extension::Set.new(
      [
        my_tracing_ext
      ]
    )

    my_create_node, create_instance = Create_fixture()

    lib_ctx, flow_options, signal = Trailblazer::Circuit::WrapRuntime::Runner.(
      my_create_node,
      {exec_context: create_instance},
      {
        application_ctx: {params: {id: 1, title: "Uwe"}},
        stack: [].freeze,
      },
      nil,
      runner: Trailblazer::Circuit::WrapRuntime::Runner,
      wrap_runtime: Hash.new(my_extensions),
      context_implementation: Trailblazer::Circuit::Context,
    )

    assert_equal signal, :Success
    assert_equal flow_options[:application_ctx], {:params=>{:id=>1, title: "Uwe", :model=>Record.new(1, "Uwe")}}

    pp flow_options[:stack]

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

