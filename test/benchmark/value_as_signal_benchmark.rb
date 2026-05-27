require "test_helper"

# Play with the idea of passing a processing value as a signal through a Circuit (that might have deciders, etc)

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

my_pipe = Trailblazer::Circuit::Builder.Pipeline(
  [:a, method(:write_to_lib_ctx), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:b, method(:write_to_lib_ctx), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:c, method(:write_to_lib_ctx), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:d, method(:write_to_lib_ctx), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:e, method(:write_to_lib_ctx), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:f, method(:write_to_lib_ctx), Trailblazer::Circuit::Task::Adapter::LibInterface],
)

my_node = Trailblazer::Circuit::Node[:id, my_pipe, Trailblazer::Circuit::Processor]

lib_ctx, flow_options, signal = run_node(my_node)
raise unless lib_ctx[:seq] == [:a, :a, :a, :a, :a, :a]

## the same, only that we don't use lib_ctx but signal

def write_to_signal(lib_ctx, flow_options, signal, **)
  signal += [:a]

  return lib_ctx, flow_options, signal
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
  d: Resolver::Fixed.new(:e),
  e: Resolver::Fixed.new(:f),
  f: Resolver::Fixed.new(:g),
}

my_nodes = {
  a: Trailblazer::Circuit::Node[:a, method(:write_to_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
  b: Trailblazer::Circuit::Node[:b, method(:write_to_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
  c: Trailblazer::Circuit::Node[:c, method(:write_to_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
  d: Trailblazer::Circuit::Node[:d, method(:write_to_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
  e: Trailblazer::Circuit::Node[:e, method(:write_to_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
  f: Trailblazer::Circuit::Node[:f, method(:write_to_signal), Trailblazer::Circuit::Task::Adapter::LibInterface],
}

my_circuit = Trailblazer::Circuit.build(flow_map: my_flow_map, nodes: my_nodes)
my_circuit_node_signal = Trailblazer::Circuit::Node[:id, my_circuit, Trailblazer::Circuit::Processor]
# pp my_circuit_node

lib_ctx, flow_options, signal = run_node(my_circuit_node_signal, signal: [])
raise unless signal == [:a, :a, :a, :a, :a, :a]

require "benchmark/ips"

Benchmark.ips do |x|
  x.report("lib_ctx") {
    run_node(my_node, signal: nil)
  }

  x.report("signal") {
    run_node(my_circuit_node_signal, signal: [])
  }

  x.compare!
end

# Comparison:
#               signal:   155745.4 i/s
#              lib_ctx:   129919.1 i/s - 1.20x  slower
