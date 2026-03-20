require "benchmark/ips"
require "test_helper"

old_circuit, _ = Trailblazer::Circuit::Builder.Circuit([:a, :a], termini: [:a])

different_circuit, _ = Trailblazer::Circuit::Builder.Circuit([:a, :a], termini: [:a])

different_circuit.start_task_id = [:a, different_circuit.nodes[:a]]
different_circuit.instance_exec do
  def start_tuple
    start_task_id
  end
end

    different_circuit.start_tuple
Benchmark.ips do |x|
  x.report("cix") {
    old_circuit.start_tuple
  }

  x.report("new") {
    different_circuit.start_tuple
  }

  x.compare!
end
