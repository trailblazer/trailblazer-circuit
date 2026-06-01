require "test_helper"

def run_node(node, lib_ctx: {}, signal: nil, flow_options: {application_ctx: {seq: []}})
  _, flow_options, _ = Trailblazer::Circuit::Node::Runner.(
    node,
    lib_ctx,
    flow_options,
    signal,
    context_implementation: Trailblazer::Circuit::Context,
    runner: Trailblazer::Circuit::Node::Runner,
  )
end

my_exec_context = T.def_tasks(:a, :b, :c, :d, :e, :f, success_signal: Right)

my_pipe = Trailblazer::Circuit::Builder.Circuit(
  [:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {Right => :b}],
  [:b, my_exec_context.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {Right => :c}],
  [:c, my_exec_context.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {Right => :d}],
  [:d, my_exec_context.method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {Right => :e}],
  [:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {Right => :f}],
  [:f, my_exec_context.method(:f), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {Right => nil}],
)

# my_node = Trailblazer::Circuit::Node::Scoped[:id, my_pipe, Trailblazer::Circuit::Processor, copy_to_outer_ctx: [:seq]]
my_node = Trailblazer::Circuit::Node[:id, my_pipe, Trailblazer::Circuit::Processor]

lib_ctx, flow_options, signal = run_node(my_node)
raise unless flow_options[:application_ctx][:seq] == [:a, :b, :c, :d, :e, :f]





class MyCircuit < Trailblazer::Circuit
  def resolve(current_node_id, signal)
    next_task_id, signal = flow_map[current_node_id].fetch(signal)
    # puts "@@@@@ #{current_node_id.inspect} / #{signal} ===> #{next_task_id}"

    return next_task_id, nodes[next_task_id], signal
  end
end

# module Resolver
#     class Fixed < Struct.new(:signal) # TODO: is it faster to use a simple PORO?
#       def fetch(_signal)
#         signal
#       end
#     end
#   end

my_flow_map = {
  a: {Right => [:b, Right]},
  b: {Right => [:c, Right]},
  c: {Right => [:d, Right]},
  d: {Right => [:e, Right]},
  e: {Right => [:f, Right]},
  f: {Right => [:g, Right]},
}


my_nodes = {
  a: Trailblazer::Circuit::Node[:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface],
  b: Trailblazer::Circuit::Node[:b, my_exec_context.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],
  c: Trailblazer::Circuit::Node[:c, my_exec_context.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface],
  d: Trailblazer::Circuit::Node[:d, my_exec_context.method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface],
  e: Trailblazer::Circuit::Node[:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface],
  f: Trailblazer::Circuit::Node[:f, my_exec_context.method(:f), Trailblazer::Circuit::Task::Adapter::LibInterface],
}

my_circuit = MyCircuit.build(flow_map: my_flow_map, nodes: my_nodes)
my_circuit_with_signal_resolve = Trailblazer::Circuit::Node[:id, my_circuit, Trailblazer::Circuit::Processor]

lib_ctx, flow_options, signal = run_node(my_circuit_with_signal_resolve)
raise unless flow_options[:application_ctx][:seq] == [:a, :b, :c, :d, :e, :f]

require "benchmark/ips"

Benchmark.ips do |x|
  x.report("circuit with 1-return-value resolve") {
    run_node(my_node)
  }

  x.report("circuit with 2-return-value resolve") {
    run_node(my_circuit_with_signal_resolve)
  }

  x.compare!
end

# Comparison:
# circuit with 1-return-value resolve:   109787.5 i/s
# circuit with 2-return-value resolve:   109126.4 i/s - same-ish: difference falls within error
