require "test_helper"

def run_node(node, lib_ctx: {target_ctx: {seq: []}}, signal: nil)
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
  [:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:b, my_exec_context.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:c, my_exec_context.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:d, my_exec_context.method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:e, my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface],
  [:f, my_exec_context.method(:f), Trailblazer::Circuit::Task::Adapter::LibInterface],
)

# require "trailblazer/developer"
# Trailblazer::Developer.puts(my_pipe)

# my_node = Trailblazer::Circuit::Node::Scoped[:id, my_pipe, Trailblazer::Circuit::Processor, copy_to_outer_ctx: [:seq]]
my_node = Trailblazer::Circuit::Node[my_pipe, Trailblazer::Circuit::Processor]

lib_ctx, flow_options, signal = run_node(my_node)
raise unless lib_ctx[:target_ctx][:seq] == [:a, :b, :c, :d, :e, :f]

class MyProcessor
  def self.call(circuit, lib_ctx, flow_options, signal, runner:, start_tuple: circuit.start_tuple, **circuit_options)
    id, node = start_tuple

    loop do
      # puts ">>>Processor #{id.inspect} <<<#{signal.inspect}>>> #{node.class} <#{lib_ctx.inspect}"
      # circuit_options = circuit_options.merge(
      #   runner: runner,
      #   node:   node, # NOTE: you can access the current node in a task via the CircuitInterface.
      #   id: id,
      # )

      lib_ctx, flow_options, signal = runner.(lib_ctx, flow_options, signal,
        **circuit_options, # DISCUSS: should we transport the :node in circuit_options, only?
        runner: runner, node: node, id: id)

      id, node, signal = circuit.resolve(id, signal) # DISCUSS: pass id and node? DISCUSS: allow returning the {signal} from resolve?

      return lib_ctx, flow_options, signal unless node
    end
  end
end

class MyRunner < Trailblazer::Circuit::Node::Runner
  def self.call(lib_ctx, flow_options, signal, **circuit_options) # DISCUSS: always transport {:node} in {circuit_options} and remove first pos arg?
    circuit_options[:node].(lib_ctx, flow_options, signal, **circuit_options) # NOTE: runner calls node with the circuit interface.
  end
end

class MyNode < Trailblazer::Circuit::Node
  def call(ctx, flow_options, signal, **circuit_options)
    # Note that the circuit_options are passed as keyword arguments to the Adapter.
    interface.(task, ctx, flow_options, signal, **circuit_options) # DISCUSS: could we pass node_processor_options to Processor.() to set a differing start task?
  end
end

my_pipe = Trailblazer::Circuit::Builder.Circuit(
  [:a, node: MyNode[my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface]],
  [:b, node: MyNode[my_exec_context.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface]],
  [:c, node: MyNode[my_exec_context.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface]],
  [:d, node: MyNode[my_exec_context.method(:d), Trailblazer::Circuit::Task::Adapter::LibInterface]],
  [:e, node: MyNode[my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface]],
  [:f, node: MyNode[my_exec_context.method(:f), Trailblazer::Circuit::Task::Adapter::LibInterface]],
)

my_node_via_circuit_options = MyNode[my_pipe, MyProcessor]

def run_node_via_circuit_options(node, lib_ctx: {target_ctx: {seq: []}}, signal: nil)
  _, flow_options, _ = MyRunner.(
    # node,
    lib_ctx,
    flow_options,
    signal,
    context_implementation: Trailblazer::Circuit::Context,
    runner: MyRunner,
    node: node
  )
end


lib_ctx, flow_options, signal = run_node_via_circuit_options(my_node_via_circuit_options)
raise unless lib_ctx[:target_ctx][:seq] == [:a, :b, :c, :d, :e, :f]


require "benchmark/ips"

Benchmark.ips do |x|
  x.report("node as pos arg") {
    run_node(my_node)
  }

  x.report("node via circuit_options") {
    run_node_via_circuit_options(my_node_via_circuit_options)
  }

  x.compare!
end

# Comparison:
# node via circuit_options:   118127.3 i/s
#      node as pos arg:   117271.0 i/s - same-ish: difference falls within error


# with kwargs
# Comparison:
#      node as pos arg:   131612.4 i/s
# node via circuit_options:   114236.9 i/s - 1.15x  slower

