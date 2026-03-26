require "test_helper"

module Activity
  Right = Class.new
  Left = Class.new
end

my_exec_context = T.def_tasks(:a, :b, :c)

def my_failure(lib_ctx, flow_options, signal)
  return lib_ctx, flow_options, :Left
end

my_circuit, termini = Trailblazer::Circuit::Builder.Circuit(
  [[:a, my_exec_context.method(:a)], {Activity::Right => :b, Activity::Left => :failure}],
  [[:b, my_exec_context.method(:b)], {Activity::Right => :c, Activity::Left => :failure}],
  [[:c, my_exec_context.method(:c)], {Activity::Right => :success, Activity::Left => :failure}],

  [[:failure, failure = method(:my_failure)]], # this basically only exists so {:c} can connect its {Left}.
  [[:success, success = method(:my_failure)]],

  termini: [:failure, :success],
)

my_node = Trailblazer::Circuit::Node[:old, my_circuit, Trailblazer::Circuit::Processor]

def run_circuit(node)
  Trailblazer::Circuit::Node::Runner.(node, {}, {application_ctx: {seq: [], b: Activity::Left}}, nil, runner: Trailblazer::Circuit::Node::Runner, context_implementation: Trailblazer::Circuit::Context)
end

lib_ctx, flow_options, signal = run_circuit(my_node)
raise flow_options.inspect unless flow_options[:application_ctx][:seq] == [:a, :b]


# Implementation where the circuit simply terminates when {signal => nil}
my_new_circuit, termini = Trailblazer::Circuit::Builder.Circuit(
  [[:a, my_exec_context.method(:a)], {Activity::Right => :b, Activity::Left => nil}],
  [[:b, my_exec_context.method(:b)], {Activity::Right => :c, Activity::Left => nil}],
  [[:c, my_exec_context.method(:c)], {Activity::Right => nil, Activity::Left => nil}],
  termini: [], # TODO: we don't need those
)

my_new_circuit.instance_eval do
  def resolve(current_node_id, signal)
    signal_map = flow_map[current_node_id] # assumption: ID must always be a symbol.

    raise "signal unknown" unless signal_map.key?(signal)

    next_task_id = signal_map[signal]# or raise "#{current_node_id}===>#{signal.inspect} @ #{signal_map}".inspect # this will be nil for a terminus.

    return next_task_id, nodes[next_task_id]
  end
end

my_new_node = Trailblazer::Circuit::Node[:new, my_new_circuit, Trailblazer::Circuit::Processor]

lib_ctx, flow_options, signal = run_circuit(my_new_node)
raise flow_options.inspect unless flow_options[:application_ctx][:seq] == [:a, :b]

require "benchmark/ips"

Benchmark.ips do |x|
  x.report("circuit with termini") {
    run_circuit(my_node)
  }

  x.report("circuit pointing to nil") {
    run_circuit(my_new_node)
  }

  x.compare!
end

# Comparison:
# circuit pointing to nil:   248685.0 i/s
# circuit with termini:   205807.8 i/s - 1.21x  slower
