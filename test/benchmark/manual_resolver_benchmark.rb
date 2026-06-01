require "test_helper"

def run_node(node, flow_options: {application_ctx: {seq: []}}, signal: nil)
  _, flow_options, _ = Trailblazer::Circuit::Node::Runner.(
    node,
    {},
    flow_options,
    signal,
    context_implementation: Trailblazer::Circuit::Context,
    runner: Trailblazer::Circuit::Node::Runner,
  )
end

my_exec_context = T.def_tasks(:a, :b, :c, :d, :e, :f, success_signal: nil)

my_pipe = Trailblazer::Circuit::Builder.Circuit(
  [:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {nil => :b}],
  [:b, my_exec_context.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {nil => :c}],
  [:c, my_exec_context.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {nil => :d}],
  [:d, my_exec_context.method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {nil => :e}],
  [:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {nil => :f}],
  [:f, my_exec_context.method(:f), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {nil => nil}],
)

my_node = Trailblazer::Circuit::Node[:id, my_pipe, Trailblazer::Circuit::Processor]

lib_ctx, flow_options, signal = run_node(my_node)
raise unless flow_options[:application_ctx][:seq] == [:a, :b, :c, :d, :e, :f]





class MyCircuit < Struct.new(:flow_map, :start_tuple, :nodes, :resolvers)
  # Automatically computes start and terminus node.
  def self.build(flow_map:, nodes:, resolvers:)
    ids           = flow_map.keys

    start_task_id = ids[0]
    start_tuple   = [start_task_id, nodes[start_task_id]]

    new(flow_map, start_tuple, nodes, resolvers)
  end

  # Find the next step for {current_node_id => signal}.
  # This is called in {MyCircuit::Processor.call}.
  def resolve(current_node_id, signal)
    next_task_id, signal = resolvers[current_node_id].resolve(flow_map, current_node_id, signal)

    return next_task_id, nodes[next_task_id], signal # TODO: can we save this lookup and optimize the map directly?
  end
end # MyCircuit

# traditional hash that can "easily" be altered via ADDS.
my_flow_map = {
  a: {nil => :b},
  b: {nil => :c},
  c: {nil => :d},
  d: {nil => :e},
  e: {nil => :f},
  f: {nil => nil},
}

my_pipeline_resolver = Class.new do # always use {nil} as signal.
  # def initialize(connections)
  #   @connections = connections
  # end

  def resolve(flow_map, current_node_id, signal)
    next_task_id = flow_map[current_node_id].fetch(nil)

    return next_task_id, signal
  end
end.new

my_resolvers = {
  a: my_pipeline_resolver,
  b: my_pipeline_resolver,
  c: my_pipeline_resolver,
  d: my_pipeline_resolver,
  e: my_pipeline_resolver,
  f: my_pipeline_resolver,
}

my_nodes = {
  a: Trailblazer::Circuit::Node[:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface],
  b: Trailblazer::Circuit::Node[:b, my_exec_context.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],
  c: Trailblazer::Circuit::Node[:c, my_exec_context.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface],
  d: Trailblazer::Circuit::Node[:d, my_exec_context.method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface],
  e: Trailblazer::Circuit::Node[:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface],
  f: Trailblazer::Circuit::Node[:f, my_exec_context.method(:f), Trailblazer::Circuit::Task::Adapter::LibInterface],
}

my_circuit = MyCircuit.build(flow_map: my_flow_map, nodes: my_nodes, resolvers: my_resolvers)

my_node_resolving = Trailblazer::Circuit::Node[:id, my_circuit, Trailblazer::Circuit::Processor]

lib_ctx, flow_options, signal = run_node(my_node_resolving)
raise unless flow_options[:application_ctx][:seq] == [:a, :b, :c, :d, :e, :f]




require "benchmark/ips"

Benchmark.ips do |x|
  x.report("traditional") {
    run_node(my_node)
  }

  x.report("resolver") {
    run_node(my_node_resolving)
  }

  x.compare!
end
