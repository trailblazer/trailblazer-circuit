require "benchmark/ips"
require "test_helper"

my_provider = ->(lib_ctx, flow_options, signal, my_value:, **) do
  lib_ctx = lib_ctx.merge(value: my_value.upcase)

  return lib_ctx, flow_options, signal
end

###
# Implementation based on kws passed around.
kw_based_exec_context = Class.new do
  def self.wrap_value_with_hash(lib_ctx, flow_options, signal, value:, write_name:, **)
    lib_ctx = lib_ctx.merge(value: {write_name => value})

    return lib_ctx, flow_options, signal
  end

  def self.add_value_to_aggregate(lib_ctx, flow_options, signal, value:, aggregate:, **)
    lib_ctx[:aggregate] = aggregate.merge(value)

    return lib_ctx, flow_options, signal
  end
end

kw_based_node = Trailblazer::Circuit::Builder.Pipeline(
  [:invoke_provider, my_provider],
  [:wrap_value_with_hash, kw_based_exec_context.method(:wrap_value_with_hash), merge_to_lib_ctx: {write_name: :model}, copy_to_outer_ctx: [:value]],
  [:add_value_to_aggregate, kw_based_exec_context.method(:add_value_to_aggregate)],
)

kw_based_node = Trailblazer::Circuit::Node::Scoped[:my_filter, kw_based_node, Trailblazer::Circuit::Processor, copy_to_outer_ctx: [:aggregate]]


def run_kw_based(node, _arg)
  Trailblazer::Circuit::Node::Runner.(node, {my_value: "Object", aggregate: {}}, {}, nil, runner: Trailblazer::Circuit::Node::Runner, context_implementation: Trailblazer::Circuit::Context)
end

lib_ctx, _ = run_kw_based(kw_based_node, nil)
raise lib_ctx.inspect unless lib_ctx == {:my_value=>"Object", aggregate: {model: "OBJECT"}}

###
# Implementation based on one instance that holds state and implementation.
state_exec_context = Struct.new(:write_name) do
  def wrap_value_with_hash(lib_ctx, flow_options, signal, value:, **)
    lib_ctx = lib_ctx.merge(value: {write_name => value})

    return lib_ctx, flow_options, signal
  end

  def add_value_to_aggregate(lib_ctx, flow_options, signal, value:, aggregate:, **)
    lib_ctx[:aggregate] = aggregate.merge(value)

    return lib_ctx, flow_options, signal
  end
end.new(:model)

state_node = Trailblazer::Circuit::Builder.Pipeline(
  [:invoke_provider, my_provider],
  [:wrap_value_with_hash, :wrap_value_with_hash, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod], # we don't need scoping here, as opposed to above.
  [:add_value_to_aggregate, :add_value_to_aggregate, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
)

state_node = Trailblazer::Circuit::Node::Scoped[:my_filter, state_node, Trailblazer::Circuit::Processor, copy_to_outer_ctx: [:aggregate]]

def run_state_based(node, exec_context)
  Trailblazer::Circuit::Node::Runner.(node, {my_value: "Object", aggregate: {}, exec_context: exec_context}, {}, nil, runner: Trailblazer::Circuit::Node::Runner, context_implementation: Trailblazer::Circuit::Context)
end

lib_ctx, _ = run_state_based(state_node, state_exec_context)
raise lib_ctx.inspect unless lib_ctx == {:my_value=>"Object", aggregate: {model: "OBJECT"}, exec_context: state_exec_context}

Benchmark.ips do |x|
  x.report("kw-based") {
    run_kw_based(kw_based_node, nil)
  }

  x.report("instance-based") {
    run_state_based(state_node, state_exec_context)
  }

  x.compare!
end

# Comparison:
#       instance-based:   172068.4 i/s
#             kw-based:   151305.7 i/s - 1.14x  slower
