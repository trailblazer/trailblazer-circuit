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

# lib_ctx, flow_options = Benchmark.run_node(my_node_with_merge, lib_ctx: {}, flow_options: {application_ctx: {seq: []}})
# lib_ctx, flow_options = Benchmark.run_node(my_node_with_method_refs, lib_ctx: {}, flow_options: {application_ctx: {seq: []}})
# lib_ctx, flow_options = Benchmark.run_node(my_node_with_instance_method_and_scoped, lib_ctx: {}, flow_options: {application_ctx: {seq: []}})
# lib_ctx, flow_options = Benchmark.run_node(my_node_with_instance_method_and_not_scoped, lib_ctx: {exec_context: my_exec_context}, flow_options: {application_ctx: {seq: []}})
#  raise flow_options.inspect



# Comparison:
#           not scoped:   144965.7 i/s
#          method refs:   142825.2 i/s - 1.01x  slower
#               scoped:   125197.7 i/s - 1.16x  slower
#       merge per step:    84383.9 i/s - 1.72x  slower


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

  x.compare!
end
