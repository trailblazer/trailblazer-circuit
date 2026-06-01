require "test_helper"

# Play with the idea of passing a processing value as a signal. However, as opposed to {value_as_signal_benchmark}
# we let two slightly different Circuit implementations run against each other.

def run_node(node, lib_ctx: {seq: []}, signal: nil)
  _, flow_options, _ = Trailblazer::Circuit::Node::Runner.(
    node,
    lib_ctx,
    {},
    signal,
    context_implementation: Trailblazer::Circuit::Context,
    runner: Trailblazer::Circuit::Node::Runner,
  )
end

def write_to_lib_ctx(lib_ctx, flow_options, signal, seq:, **)
  seq += [:a]

  return lib_ctx.merge(seq: seq), flow_options, signal
end

def d(lib_ctx, flow_options, signal, seq:, **)
  seq += [:d]

  return lib_ctx.merge(seq: seq), flow_options, Right
end

my_pipe = Trailblazer::Circuit::Builder.Circuit(
  [:a, method(:write_to_lib_ctx), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {nil => :b}],
  [:b, method(:write_to_lib_ctx), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {nil => :c}],
  [:c, method(:write_to_lib_ctx), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {nil => :d}],
  [:d, method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {Right => :e, Left => :f}],
  [:e, method(:write_to_lib_ctx), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {Right => :f}], # well, problem here is, this is Right from {d}
  [:f, method(:write_to_lib_ctx), Trailblazer::Circuit::Task::Adapter::LibInterface, connections: {Right => nil}],
)

# my_node = Trailblazer::Circuit::Node::Scoped[:id, my_pipe, Trailblazer::Circuit::Processor, copy_to_outer_ctx: [:seq]]
my_node = Trailblazer::Circuit::Node::Scoped[:id, my_pipe, Trailblazer::Circuit::Processor]

lib_ctx, flow_options, signal = run_node(my_node)
# raise unless lib_ctx[:seq] == [:a, :a, :a, :d, :a, :a]

# raise "make Circuit with resolve that decomposes signal when needed vv"

## we write to signal, but the Circuit#resolve logic needs an {if}

def write_to_signal(lib_ctx, flow_options, signal, **)
  signal += [:a]

  return lib_ctx, flow_options, signal
end

def write_to_signal_and_emit_signal(lib_ctx, flow_options, signal, **)
  signal += [:d]

  return lib_ctx, flow_options, MyArray[Right, signal]
end

MyArray = Class.new(Array)

class MyCircuit < Trailblazer::Circuit
  def resolve(current_node_id, signal)
    if signal.is_a?(MyArray)
      decision, signal = signal

      next_task_id = flow_map[current_node_id].fetch(decision)
      return next_task_id, nodes[next_task_id], signal
    end

    super
  end
end

module Resolver
    class Fixed < Struct.new(:signal) # TODO: is it faster to use a simple PORO?
      def fetch(_signal)
        signal
      end
    end
  end

my_flow_map = {
  a: Resolver::Fixed.new(:b),
  b: Resolver::Fixed.new(:c),
  c: Resolver::Fixed.new(:d),
  d: {Right => :e, Left => :f},
  e: Resolver::Fixed.new(:f),
  f: Resolver::Fixed.new(:g),
}

my_nodes = {
  a: Trailblazer::Circuit::Node[:a, method(:write_to_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
  b: Trailblazer::Circuit::Node[:b, method(:write_to_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
  c: Trailblazer::Circuit::Node[:c, method(:write_to_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
  d: Trailblazer::Circuit::Node[:d, method(:write_to_signal_and_emit_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
  e: Trailblazer::Circuit::Node[:e, method(:write_to_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
  f: Trailblazer::Circuit::Node[:f, method(:write_to_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
}

my_circuit = MyCircuit.build(flow_map: my_flow_map, nodes: my_nodes)
my_circuit_node_signal = Trailblazer::Circuit::Node[:id, my_circuit, Trailblazer::Circuit::Processor]
# pp my_circuit_node

lib_ctx, flow_options, signal = run_node(my_circuit_node_signal, signal: [])
raise unless signal == [:a, :a, :a, :d, :a, :a]

## Circuit#resolve expects two return values from {fetch}. that way, we can transport the signal ("decision") along with the "value" in one object.

class MyOtherCircuit < Trailblazer::Circuit
  def resolve(current_node_id, signal)
    next_task_id, signal = flow_map[current_node_id].fetch(signal) # we return next_task_id and the signal

    return next_task_id, nodes[next_task_id], signal
  end
end

module Resolver
    class Fixed_with_Signal < Struct.new(:next_task_id)
      def fetch(signal)
        return next_task_id, signal
      end
    end

    class Decider < Struct.new(:signals_to_next)
      def fetch(signal)
        decision, signal = signal

        return signals_to_next.fetch(decision), signal
      end
    end
  end

my_flow_map = {
  a: Resolver::Fixed_with_Signal.new(:b),
  b: Resolver::Fixed_with_Signal.new(:c),
  c: Resolver::Fixed_with_Signal.new(:d),
  d: Resolver::Decider.new({Right => :e, Left => :f}),
  e: Resolver::Fixed_with_Signal.new(:f),
  f: Resolver::Fixed_with_Signal.new(:g),
}

my_circuit = MyOtherCircuit.build(flow_map: my_flow_map, nodes: my_nodes)
my_circuit_node_signal_two_values = Trailblazer::Circuit::Node[:id, my_circuit, Trailblazer::Circuit::Processor]
# pp my_circuit_node

lib_ctx, flow_options, signal = run_node(my_circuit_node_signal_two_values, signal: [])
pp signal
raise unless signal == [:a, :a, :a, :d, :a, :a]

require "benchmark/ips"

Benchmark.ips do |x|
  x.report("lib_ctx") {
    run_node(my_node, signal: nil)
  }

  x.report("signal") {
    run_node(my_circuit_node_signal, signal: [])
  }

  x.report("signal two values") {
    run_node(my_circuit_node_signal_two_values, signal: [])
  }

  x.compare!
end


# Comparison:
#               signal:   131801.5 i/s
#              lib_ctx:   115187.5 i/s - 1.14x  slower

# Comparison:
#    signal two values:   135250.0 i/s
#               signal:   132495.7 i/s - 1.02x  slower
#              lib_ctx:   113279.9 i/s - 1.19x  slower


# With Node::Scope vs Node/signal
#
# Comparison:
#    signal two values:   143825.1 i/s
#               signal:   140276.8 i/s - 1.03x  slower
#              lib_ctx:   104034.5 i/s - 1.38x  slower

