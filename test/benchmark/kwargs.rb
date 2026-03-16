require "test_helper"

gem "benchmark-ips"
require "benchmark/ips"

# # Learning
#
#          positional: 19719128.3 i/s
#              kwargs: 14139622.2 i/s - 1.39x  (± 0.00) slower

def positional(a, b, c, d)
end

def kwargs(a:, b:, c:, d:)
end

Benchmark.ips do |x|
  x.report("positional") { positional(1, 2, 3, 4) }
  x.report("kwargs") { kwargs(a: 1, b: 2, c: 3, d: 4) }

  x.compare!
end
