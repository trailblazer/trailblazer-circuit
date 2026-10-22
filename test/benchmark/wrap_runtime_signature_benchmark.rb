require "test_helper"
require "benchmark/ips"

my_old_extension = ->(node:, **circuit_options) { circuit_options.merge(node: node) }

my_pipeline = Trailblazer::Circuit::Builder.Pipeline(
  [:a, T.def_task(:a, success_signal: nil)],
  [:b, T.def_task(:b, success_signal: nil)],
  [:c, T.def_task(:c, success_signal: nil)],
  [:d, T.def_task(:d, success_signal: nil)],
)

my_pipeline_node = Trailblazer::Circuit::Node[my_pipeline, Trailblazer::Circuit::Processor]

my_new_extension = ->(lib_ctx, flow_options, signal, node:, **circuit_options) { [lib_ctx, flow_options, signal, circuit_options.merge(node: node)] }

class MyRunner < Trailblazer::Circuit::Node::Runner
  def self.call(lib_ctx, flow_options, signal, wrap_runtime:, **circuit_options)

    lib_ctx, flow_options, signal, circuit_options = wrap_runtime.(lib_ctx, flow_options, signal, **circuit_options)
    super(lib_ctx, flow_options, signal, **circuit_options, wrap_runtime: wrap_runtime)
  end
end

pp MyRunner.(
      {target_ctx: {seq: []}}, {}, nil,
      runner: MyRunner, context_implementation: Trailblazer::Circuit::Context,
      wrap_runtime: ->(*args, **circuit_options) { my_new_extension.(*args, **circuit_options) },
      node: my_pipeline_node
    )

Benchmark.ips do |x|
  x.report("circuit_options") {
    Trailblazer::Circuit::WrapRuntime::Runner.(
      {target_ctx: {seq: []}}, {}, nil,
      runner: Trailblazer::Circuit::WrapRuntime::Runner, context_implementation: Trailblazer::Circuit::Context,
      wrap_runtime: ->(**circuit_options) { my_old_extension.(**circuit_options) },
      node: my_pipeline_node
    )
  }

  x.report("all") {
    MyRunner.(
      {target_ctx: {seq: []}}, {}, nil,
      runner: MyRunner, context_implementation: Trailblazer::Circuit::Context,
      wrap_runtime: ->(*args, **circuit_options) { my_new_extension.(*args, **circuit_options) },
      node: my_pipeline_node
    )
  }

  x.compare!
end

# 3.0.0
# Calculating -------------------------------------
#      circuit_options    107.844k (± 1.1%) i/s    (9.27 μs/i) -    540.500k in   5.012537s
#                  all     74.737k (± 1.0%) i/s   (13.38 μs/i) -    374.250k in   5.008107s

# Comparison:
#      circuit_options:   107843.6 i/s
#                  all:    74737.0 i/s - 1.44x  slower

# 3.3.6
# Comparison:
#      circuit_options:    90223.8 i/s
#                  all:    84292.4 i/s - 1.07x  slower
