require "test_helper"

# Let a Pipeline run against a Circuit with Resolver::Fixed.

def run_node(node, application_ctx: {seq: []})
  _, flow_options, _ = Trailblazer::Circuit::Node::Runner.(
    node,
    {},
    {application_ctx: application_ctx},
    nil,
    context_implementation: Trailblazer::Circuit::Context,
    runner: Trailblazer::Circuit::Node::Runner,
  )
end

my_exec_context = T.def_tasks(:a, :b, :c, :d, :e, :f, :g, :h, success_signal: Right)

my_pipe = Trailblazer::Circuit::Builder.Pipeline(
  [:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:b, my_exec_context.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:c, my_exec_context.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:d, my_exec_context.method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:f, my_exec_context.method(:f), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:g, my_exec_context.method(:g), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:h, my_exec_context.method(:h), Trailblazer::Circuit::Task::Adapter::LibInterface],
)

my_node = Trailblazer::Circuit::Node[:id, my_pipe, Trailblazer::Circuit::Processor]

lib_ctx, flow_options, signal = run_node(my_node)
raise unless flow_options[:application_ctx][:seq] == [:a, :b, :c, :d, :e, :f, :g, :h]


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
  g: Resolver::Fixed.new(:h),
  h: Resolver::Fixed.new(nil),
}

my_nodes = {
  a: Trailblazer::Circuit::Node[:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface],
  b: Trailblazer::Circuit::Node[:b, my_exec_context.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],
  c: Trailblazer::Circuit::Node[:c, my_exec_context.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface],
  d: Trailblazer::Circuit::Node[:d, my_exec_context.method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface],
  e: Trailblazer::Circuit::Node[:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface],
  f: Trailblazer::Circuit::Node[:f, my_exec_context.method(:f), Trailblazer::Circuit::Task::Adapter::LibInterface],
  g: Trailblazer::Circuit::Node[:g, my_exec_context.method(:g), Trailblazer::Circuit::Task::Adapter::LibInterface],
  h: Trailblazer::Circuit::Node[:h, my_exec_context.method(:h), Trailblazer::Circuit::Task::Adapter::LibInterface],
}

my_circuit = Trailblazer::Circuit.build(flow_map: my_flow_map, nodes: my_nodes)
my_circuit_node = Trailblazer::Circuit::Node[:id, my_circuit, Trailblazer::Circuit::Processor]
# pp my_circuit_node

lib_ctx, flow_options, signal = run_node(my_circuit_node)
raise unless flow_options[:application_ctx][:seq] == [:a, :b, :c, :d, :e, :f, :g, :h]


require "benchmark/ips"

Benchmark.ips do |x|
  x.report("pipeline") {
    run_node(my_node)
  }

  x.report("circuit w/ fixed") {
    run_node(my_circuit_node)
  }

  # x.report("circuit w/ fixed PORO") {
  #   run_node(my_circuit_node__)
  # }

  x.compare!
end
# Comparison:
#             pipeline:    94176.6 i/s
#     circuit w/ fixed:    93820.6 i/s - same-ish: difference falls within error

# Comparison:
#             pipeline:    96883.2 i/s
#     circuit w/ fixed:    94985.5 i/s - 1.02x  slower
# circuit w/ fixed PORO:    94131.9 i/s - 1.03x  slower
