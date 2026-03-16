require "test_helper"

class WrapRuntimeTest < Minitest::Spec
  def assert_stack(actual, expected)
    assert_equal actual.size, expected.size

    actual.each_with_index do |capture, i|
      assert_equal capture, expected[i]
    end
  end

  it "wrap_runtime prototyping" do
    create_circuit, create_outputs, _, _, validate_outputs, save_tw_pipe = Fixtures.fixtures

    ctx = {params: {song: nil}, slug: 666}

    class MyTrace
      def self.capture_before(lib_ctx, flow_options, signal, task:, **) # FIXME: we need circuit_options for the {:task}.
        stack = flow_options.fetch(:stack)

        stack += [[:before, task, flow_options[:application_ctx].to_h.inspect]] # treat stack as an immutable object
# puts "         ~~~ trace in #{task.inspect}: #{}"

        return lib_ctx, flow_options.merge(stack: stack), signal
      end

      def self.capture_after(lib_ctx, flow_options, signal, task:, **) # FIXME: we need circuit_options for the {:task}.
        stack = flow_options.fetch(:stack)

        stack += [[:after, task, flow_options[:application_ctx].to_h.inspect, signal]]

        # puts "@@@@@ CA, #{task} #{signal.inspect}"

        return lib_ctx, flow_options.merge(stack: stack), signal
      end
    end

    # DISCUSS: how to merge multiple runtime extensions? canonical invoke!
    my_tw_extension = _A::Circuit::WrapRuntime::Extension.new(
      [
        [Trailblazer::Circuit::Node::Scoped[id: :capture_before, task: :capture_before, interface: Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: MyTrace},
          copy_to_outer_ctx: [:stack]], :before],
        [Trailblazer::Circuit::Node::Scoped[id: :capture_after, task: :capture_after, interface: Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: MyTrace},
          copy_to_outer_ctx: [:stack]], :after],
      ]
    )

    my_wrap_runtime_runner = _A::Circuit::WrapRuntime::Runner

# DEBUGGING

# call save's taskWrap:
save_call_task_node = save_tw_pipe.config[:"task_wrap.call_task"]

    ctx, lib_ctx, signal = my_wrap_runtime_runner.(
      save_call_task_node,
      {},
      {
        application_ctx: {model: Object},
        stack: [].freeze,
      },
      nil,
      runner: my_wrap_runtime_runner,
      wrap_runtime: Hash.new(my_tw_extension),
      context_implementation: Trailblazer::Circuit::Context,
    )

    assert_equal lib_ctx[:stack],
      [[:before, :"task_wrap.call_task", "{:model=>Object}"], [:after, :"task_wrap.call_task", "{:model=>Object, :save=>Object}", Trailblazer::Activity::Right]]

# call Model's taskWrap:
    model_tw_node = create_circuit.config[:"model.task_wrap"]

    lib_ctx, flow_options, signal = my_wrap_runtime_runner.(
      model_tw_node,
      {},
      {
        application_ctx: {params: {}, slug: "0x999"},
        stack: [].freeze,
      },
      nil,
      runner: my_wrap_runtime_runner,
      wrap_runtime: Hash.new(my_tw_extension),
      context_implementation: Trailblazer::Circuit::Context,
    )


    assert_equal flow_options[:stack][8], [:after, :"task_wrap.call_task", "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\", :spam=>false, :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}", Trailblazer::Activity::Right]

    assert_equal flow_options[:stack], [
      [:before, :"model.task_wrap", "{:params=>{}, :slug=>\"0x999\"}"],
      [:before, :input, "{:params=>{}, :slug=>\"0x999\"}"],
      [:before, :my_model_input, "{:params=>{}, :slug=>\"0x999\"}"],
      [:after, :my_model_input, "{:params=>{}, :slug=>\"0x999\"}", nil],
      [:before, :more_model_input, "{:params=>{}, :slug=>\"0x999\"}"],
      [:after, :more_model_input, "{:params=>{}, :slug=>\"0x999\"}", nil],
      [:after, :input, "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\"}", nil],
      [:before, :"task_wrap.call_task", "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\"}"],
      [:after, :"task_wrap.call_task", "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\", :spam=>false, :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}", Trailblazer::Activity::Right],
      [:before, :output, "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\", :spam=>false, :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}"],
      [:before, :my_model_output, "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\", :spam=>false, :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}"],
      [:after, :my_model_output, "{:params=>{:slug=>\"0x999\"}, :more=>\"0x999\", :spam=>false, :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}", nil],
      [:after, :output, "{:params=>{}, :slug=>\"0x999\", :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}", nil],
      [:after, :"model.task_wrap", "{:params=>{}, :slug=>\"0x999\", :model=>\"Object  / {:more=>\\\"0x999\\\"}\"}", Trailblazer::Activity::Right]
    ]


# raise "wooohoo"
tw_create_pipe = Trailblazer::Circuit::Builder.TaskWrap(
      [:"task_wrap.call_task", create_circuit, Trailblazer::Circuit::Processor, {}, Trailblazer::Circuit::Node::Scoped]
    )

    canonical_node = Trailblazer::Circuit::Node::Scoped[id: :Create, task: tw_create_pipe, interface: Trailblazer::Circuit::Processor]
puts "yo"
    ctx = {params: {song: nil}, slug: 666}

    # validation error:
    lib_ctx, flow_options, signal = my_wrap_runtime_runner.( # we don't need another circuit around the OP tw, do we?
      canonical_node,
      {},
      {
        application_ctx: ctx,
        stack: [].freeze,
      },
      nil,
      runner: my_wrap_runtime_runner,
      wrap_runtime: Hash.new(my_tw_extension),
      context_implementation: Trailblazer::Circuit::Context,
    )

    assert_equal flow_options[:application_ctx], {:params=>{:song=>nil}, slug: 666, :model=>"Object  / {:more=>666}", :errors=>["Object  / {:more=>666}", :song]}
    assert_equal lib_ctx.keys, []
    assert_equal flow_options.keys, [:application_ctx, :stack]
    assert_equal signal, create_outputs[:failure]

    pp flow_options[:stack]

    # raise ":task in failure is wrong "
    assert_stack flow_options[:stack], [
      [:before, :Create, "{:params=>{:song=>nil}, :slug=>666}"],
      [:before, :"model.task_wrap", "{:params=>{:song=>nil}, :slug=>666}"],
      [:before, :input, "{:params=>{:song=>nil}, :slug=>666}"],
      [:before, :my_model_input, "{:params=>{:song=>nil}, :slug=>666}"],
      [:after, :my_model_input, "{:params=>{:song=>nil}, :slug=>666}", nil],
      [:before, :more_model_input, "{:params=>{:song=>nil}, :slug=>666}"],
      [:after, :more_model_input, "{:params=>{:song=>nil}, :slug=>666}", nil],
      [:after, :input, "{:params=>{:song=>nil, :slug=>666}, :more=>666}", nil],
      [:before, :"task_wrap.call_task", "{:params=>{:song=>nil, :slug=>666}, :more=>666}"],
      [:after, :"task_wrap.call_task", "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}", Trailblazer::Activity::Right],

       [:before, :output, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}"],
       [:before, :my_model_output, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}"],
       [:after, :my_model_output, "{:params=>{:song=>nil, :slug=>666}, :more=>666, :spam=>false, :model=>\"Object  / {:more=>666}\"}", nil],
       [:after, :output, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}", nil],
       [:after, :"model.task_wrap", "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}", Trailblazer::Activity::Right],
       [:before, :"validate.task_wrap", "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}"],
        [:before, :run_checks, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\"}"],
        [:after, :run_checks, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", Trailblazer::Activity::Left],
        [:before, :failure, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}"],
        [:after, :failure, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", validate_outputs[:failure]],
        [:after, :"validate.task_wrap", "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", validate_outputs[:failure]],
        [:before, :failure, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}"],
        [:after, :failure, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", validate_outputs[:failure]],
        [:after, :Create, "{:params=>{:song=>nil}, :slug=>666, :model=>\"Object  / {:more=>666}\", :errors=>[\"Object  / {:more=>666}\", :song]}", validate_outputs[:failure]]
    ]

  end
end
