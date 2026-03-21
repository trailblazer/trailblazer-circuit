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

def run_instance_method(pipe, exec_context)
  lib_ctx, flow_options, signal = Trailblazer::Circuit::Processor.(
    pipe,
    {exec_context: exec_context},
    {application_ctx: {seq: []}},
    nil,
    context_implementation: Trailblazer::Circuit::Context,
    runner: Trailblazer::Circuit::Node::Runner,
  )
end

my_input_pipe_with_method_refs = Trailblazer::Circuit::Builder.Pipeline(
  [:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:b, my_exec_context.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:c, my_exec_context.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:d, my_exec_context.method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface],
)

my_input_pipe_with_instance_but_no_scope = Trailblazer::Circuit::Builder.Pipeline(
  [:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
  [:b, :b, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
  [:c, :c, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
  [:d, :d, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
  [:e, :e, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
)

# lib_ctx, flow_options = run_instance_method(my_input_pipe_with_instance_but_no_scope, my_exec_context)
# raise flow_options.inspect


# Comparison:
#             no merge:   160634.9 i/s
#                  new:   156270.5 i/s - 1.03x  slower
#                  cix:    98281.9 i/s - 1.63x  slower


Benchmark.ips do |x|
  x.report("cix") {
    run_instance_method(my_input_pipe, my_exec_context)
  }

  x.report("new") {
    run_instance_method(my_input_pipe_with_method_refs, my_exec_context)
  }

  x.report("no merge") {
    run_instance_method(my_input_pipe_with_instance_but_no_scope, my_exec_context)
  }

  x.compare!
end
