require "benchmark/ips"
require "test_helper"

my_elements = [
  [:a, :a],
  [:b, :a],
  [:c, :a],
  [:d, :a],
]

my_pipe = Trailblazer::Circuit::Builder.Pipeline(
  *my_elements
)

def insert_via_adds(pipe)
  new_element = Trailblazer::Circuit::Node[:id, :bla, nil]

  Trailblazer::Circuit::Adds.(pipe, [new_element, :after, :b])
end

def insert_via_ary(ary)
  ary = ary.dup

  new_element = [:id, :bla]

  index = ary.index { |el| el[0] == :b } + 1
  ary.insert(index, new_element)

  Trailblazer::Circuit::Builder.Pipeline(*ary)
end

pp insert_via_adds(my_pipe)
pp insert_via_ary(my_elements)


Benchmark.ips do |x|
  x.report("adds") {
    insert_via_adds(my_pipe)
  }

  x.report("ary") {
    insert_via_ary(my_elements)
  }

  x.compare!
end

# Calculating -------------------------------------
#                 adds    336.872k (± 1.8%) i/s    (2.97 μs/i) -      1.690M in   5.016919s
#                  ary    113.015k (± 4.6%) i/s    (8.85 μs/i) -    566.304k in   5.022324s

# Comparison:
#                 adds:   336872.2 i/s
#                  ary:   113015.5 i/s - 2.98x  slower
