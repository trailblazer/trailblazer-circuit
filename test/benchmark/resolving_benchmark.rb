require "test_helper"

require "benchmark/ips"

# "current" style.
Flow_map_entry = {nil => :a}.freeze

def resolve(_signal) # pipeline resolver
  Flow_map_entry.fetch(nil)
end

@resolver = Class.new do
  def initialize
    @next_step_id = :a
  end

  def fetch(_signal)
    @next_step_id
  end
end.new()

def resolve_via_resolver(_signal)
  @resolver.fetch(_signal)
end



Benchmark.ips do |x|
  x.report("simple Hash#fetch") {
    resolve(Object)
  }

  x.report("resolver") {
    resolve_via_resolver(Object)
  }

  x.compare!
end

# Comparison:
#             resolver: 18372581.5 i/s
#    simple Hash#fetch: 13507813.9 i/s - 1.36x  slower
