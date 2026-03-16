require "test_helper"

gem "benchmark-ips"
require "benchmark/ips"

# ## Learning
#
# array decompose is only slightly slower.
# splat is super slow
# old "complicated" API is more versatile as it doesn't enforce a set of positional args,
# we only have one and the circuit_options
#

def old_circuit_api_doublesplat((ctx, flow_options), **_circuit_options)
  ctx[:in] = 1
  return 1, [ctx, flow_options]
end

def old_circuit_api_return((ctx, flow_options), _circuit_options)
  ctx[:in] = 1
  return 1, [ctx, flow_options]
end

def old_circuit_api((ctx, flow_options), _circuit_options)
  ctx[:in] = 1
  [1, [ctx, flow_options]]
end

def new_circuit_api(ctx, flow_options, _circuit_options)
  ctx[:in] = 1
  [1, [ctx, flow_options]]
end

def new_circuit_api_shortened(ctx, *args)
  ctx[:in] = 1
  [1, [ctx, *args]]
end

ctx = {}
flow_options = {}
circuit_options = {}

Benchmark.ips do |x|
  old_signature = [ctx, flow_options]

  x.report("old_circuit_api_doublesplat") { old_circuit_api_doublesplat(old_signature, circuit_options) }
  x.report("old_circuit_api") { old_circuit_api(old_signature, circuit_options) }
  x.report("old_circuit_api_return") { old_circuit_api_return(old_signature, circuit_options) }
  x.report("new_circuit_api") { new_circuit_api(ctx, flow_options, circuit_options) }
  x.report("new_short_api")   { new_circuit_api_shortened(ctx, flow_options, circuit_options) }

  x.compare!
end
