require "benchmark/ips"
require "test_helper"

my_exec_context = T.def_tasks(:a, :b, :c, :d, :e, success_signal: :Right)

# here, we benchmark something like an Input pipeline with different implementations.
#
# ACTUALLY, THIS BENCHMARK DIDN'T BRING ANY INSIGHTS, Scoped is still only .04x slower.
#

my_exec_context.instance_exec do
  def add_to_aggregate(lib_ctx, flow_options, signal, aggregate:, **)
    lib_ctx = lib_ctx.merge(aggregate: aggregate += [1])

    return lib_ctx, flow_options, signal
  end
end

my_scoped_input_nodes = (1..10).collect do |i|
  my_unscoped_pipe = Trailblazer::Circuit::Builder.Pipeline(
    [:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
    [:b, :b, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
    [:c, :c, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
    [:d, :d, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
    [:e, :add_to_aggregate, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
  )

  my_node = Trailblazer::Circuit::Node::Scoped[nil, my_unscoped_pipe, Trailblazer::Circuit::Processor,
    merge_to_lib_ctx: {exec_context: my_exec_context}, copy_to_outer_ctx: [:aggregate]
  ]

  [i, {node: my_node}]
end

my_scoped_pipe = Trailblazer::Circuit::Builder.Pipeline(*my_scoped_input_nodes)

my_scoped_filter_node = Trailblazer::Circuit::Node[nil, my_scoped_pipe, Trailblazer::Circuit::Processor]


#
# With circuit_options
#
my_co_input_nodes = (1..10).collect do |i|
  my_filter_pipe = Trailblazer::Circuit::Builder.Pipeline(
    [:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod_CircuitOptions],
    [:b, :b, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod_CircuitOptions],
    [:c, :c, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod_CircuitOptions],
    [:d, :d, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod_CircuitOptions],
    [:e, :add_to_aggregate, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod_CircuitOptions],
  )

  my_node = Trailblazer::Circuit::Node::MergeToCircuitOptions[nil, my_filter_pipe, Trailblazer::Circuit::Processor,
    exec_context: my_exec_context
  ]

  [i, {node: my_node}]
end
my_scoped_pipe = Trailblazer::Circuit::Builder.Pipeline(*my_co_input_nodes)

my_co_filter_node = Trailblazer::Circuit::Node[nil, my_scoped_pipe, Trailblazer::Circuit::Processor]


# lib_ctx, flow_options = Benchmark.run_node(my_scoped_filter_node, lib_ctx: {aggregate: []}, flow_options: {application_ctx: {seq: []}})
# lib_ctx, flow_options = Benchmark.run_node(my_co_filter_node, lib_ctx: {aggregate: []}, flow_options: {application_ctx: {seq: []}})
 # raise flow_options.inspect
# raise lib_ctx.inspect

require 'ruby-prof'

result = RubyProf::Profile.profile do
  Benchmark.run_node(my_co_filter_node, lib_ctx: {aggregate: []}, flow_options: {application_ctx: {seq: []}})
end

# print a graph profile to text
# printer = RubyProf::FlameGraphPrinter.new(result) # FlameGraphPrinter
# printer.print(File.open("flame_graph-co.html", "w"))
# raise

require "benchmark/ips"

Benchmark.ips do |x|
  x.report("Scoped") {
    Benchmark.run_node(my_scoped_filter_node, lib_ctx: {aggregate: []}, flow_options: {application_ctx: {seq: []}})
  }

  x.report("MergeToCircuitOptions") {
    Benchmark.run_node(my_co_filter_node, lib_ctx: {aggregate: []}, flow_options: {application_ctx: {seq: []}})
  }

  x.compare!
end


# Comparison:
# MergeToCircuitOptions:    13521.6 i/s
#               Scoped:    13034.1 i/s - 1.04x  slower


# Comparison: [4.0.5]
# MergeToCircuitOptions:    14510.8 i/s
#               Scoped:    13869.0 i/s - 1.05x  slower

