require "benchmark/ips"
require "test_helper"

my_exec_context = T.def_tasks(:a, :b, :c, :d, :e, success_signal: :Right)

# This was my first design choice, always call an instance method.
my_input_pipe = Trailblazer::Circuit::Builder.Pipeline(
  [:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: my_exec_context}],
  [:b, :b, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: my_exec_context}],
  [:c, :c, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: my_exec_context}],
  [:d, :d, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: my_exec_context}],
  [:e, :e, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: my_exec_context}],
)
my_node_with_merge = Trailblazer::Circuit::Node[nil, my_input_pipe, Trailblazer::Circuit::Processor]

#
# Reference the method of a particular exec_context that holds the configuration state for this pipe.
# NOTE: it would be interesting to see memory consumption here.
#
my_input_pipe_with_method_refs = Trailblazer::Circuit::Builder.Pipeline(
  [:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:b, my_exec_context.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:c, my_exec_context.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:d, my_exec_context.method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface],
)
my_node_with_method_refs = Trailblazer::Circuit::Node[nil, my_input_pipe_with_method_refs, Trailblazer::Circuit::Processor]


my_input_pipe_with_instance_but_no_scope = Trailblazer::Circuit::Builder.Pipeline(
  [:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
  [:b, :b, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
  [:c, :c, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
  [:d, :d, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
  [:e, :e, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
)
my_node_with_instance_method_and_scoped = Trailblazer::Circuit::Node::Scoped[nil, my_input_pipe_with_instance_but_no_scope, Trailblazer::Circuit::Processor,
  merge_to_lib_ctx: {exec_context: my_exec_context}
]

# we can also pass the {:exec_context} in the call, just to see how that performs.
my_node_with_instance_method_and_not_scoped = Trailblazer::Circuit::Node[nil, my_input_pipe_with_instance_but_no_scope, Trailblazer::Circuit::Processor]


#
# a new approach, check if we can have fast(er)™ scoping for something like VM::Filter, that doesn't really need a lot of variables
#

class MyFasterNode < Trailblazer::Circuit::Node::Scoped
  def scope(outer_ctx, flow_options, outer_signal, **)
          # context_implementation.scope(outer_ctx, copy_from_outer_ctx, merge_to_lib_ctx) # FIXME: {copy_from_outer_ctx} and {merge_to_lib_ctx} are attrs.
    outer_ctx.merge(merge_to_lib_ctx) # what if we know the outer_ctx gets disposed of anyway?
  end

  # @private
  def unscope(lib_ctx, outer_ctx, signal, outer_signal, **)
    # raise lib_ctx.inspect
    return {aggregate: 1}, outer_signal # this would be aggregate
  end
end

my_node_with_instance_method_and_faster_scoped = MyFasterNode[nil, my_input_pipe_with_instance_but_no_scope,
  Trailblazer::Circuit::Processor,
  merge_to_lib_ctx: {exec_context: my_exec_context}
]

# lib_ctx, flow_options = Benchmark.run_node(my_node_with_merge, lib_ctx: {}, flow_options: {application_ctx: {seq: []}})
# lib_ctx, flow_options = Benchmark.run_node(my_node_with_method_refs, lib_ctx: {}, flow_options: {application_ctx: {seq: []}})
# lib_ctx, flow_options = Benchmark.run_node(my_node_with_instance_method_and_scoped, lib_ctx: {}, flow_options: {application_ctx: {seq: []}})
# lib_ctx, flow_options = Benchmark.run_node(my_node_with_instance_method_and_not_scoped, lib_ctx: {exec_context: my_exec_context}, flow_options: {application_ctx: {seq: []}})
# lib_ctx, flow_options = Benchmark.run_node(my_node_with_instance_method_and_faster_scoped, lib_ctx: {}, flow_options: {application_ctx: {seq: []}})
#  raise flow_options.inspect


# Comparison:
#           not scoped:   145257.5 i/s
#          method refs:   140706.1 i/s - 1.03x  slower
#        faster scoped:   133354.9 i/s - 1.09x  slower
#               scoped:   126091.3 i/s - 1.15x  slower
#       merge per step:    83178.6 i/s - 1.75x  slower


Benchmark.ips do |x|
  x.report("merge per step") {
    Benchmark.run_node(my_node_with_merge, lib_ctx: {}, flow_options: {application_ctx: {seq: []}})
  }

  x.report("method refs") {
    Benchmark.run_node(my_node_with_method_refs, lib_ctx: {}, flow_options: {application_ctx: {seq: []}})
  }

  x.report("scoped") {
    Benchmark.run_node(my_node_with_instance_method_and_scoped, lib_ctx: {}, flow_options: {application_ctx: {seq: []}})
  }

  x.report("not scoped") {
    Benchmark.run_node(my_node_with_instance_method_and_not_scoped, lib_ctx: {exec_context: my_exec_context}, flow_options: {application_ctx: {seq: []}})
  }

  x.report("faster scoped") {
    Benchmark.run_node(my_node_with_instance_method_and_faster_scoped, lib_ctx: {}, flow_options: {application_ctx: {seq: []}})
  }

  x.compare!
end
