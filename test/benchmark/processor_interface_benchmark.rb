require "test_helper"
require "benchmark/ips"

class MyOldAdapter
  def self.call(_, lib_ctx, flow_options, signal, node:, **circuit_options)
    # with an adapter that doesn't do anything but extracting the node, we don't need tasks.
    return lib_ctx, flow_options, signal
  end
end

old_nested_circuit = Trailblazer::Circuit::Builder.Circuit(
  *((1..10).collect { |i| [i, nil, MyOldAdapter] })
)

old_circuit_node = Trailblazer::Circuit.Builder(
  *((1..10).collect { |i| [i, old_nested_circuit, Trailblazer::Circuit::Processor] })
)

Trailblazer::Circuit::Node::Runner.({}, {}, nil, node: old_circuit_node, runner: Trailblazer::Circuit::Node::Runner)



class MyAdapter
  def self.call(_, lib_ctx, flow_options, signal, runner, node, id)
    # with an adapter that doesn't do anything but extracting the node, we don't need tasks.
    return lib_ctx, flow_options, signal
  end
end

class MyNode < Trailblazer::Circuit::Node
  def call(lib_ctx, flow_options, signal, runner, node, id)
    adapter.(task, lib_ctx, flow_options, signal, runner, node, id)
  end
end

class MyProcessor
  # TODO: this can still be optimized for runtime speed, even though I spent days on it already.
  def self.call(circuit, lib_ctx, flow_options, signal, runner, _, _)
    id, node = circuit.start_tuple # DISCUSS: this could also be done in the "Adapter", and the Processor could be the tas

    loop do
      # puts ">>>Processor #{id.inspect} <<<#{signal.inspect}>>> #{node.class} #{lib_ctx[:target_ctx].to_h}"
      lib_ctx, flow_options, signal = runner.(
        lib_ctx,
        flow_options,
        signal,
        # **circuit_options,
        runner,
        node, # NOTE: you can access the current node in a task via the CircuitInterface.
        id,
      )

      id, node, signal = circuit.resolve(id, signal) # DISCUSS: pass id and node?

      return lib_ctx, flow_options, signal unless node
      # unless ()

        # raise_illegal_signal_error!(task, signal, @map[task], **circuit_options)
      # end
    end
  end
end

class MyRunner
  def self.call(lib_ctx, flow_options, signal, runner, node, id)
    node.(lib_ctx, flow_options, signal, runner, node, id)
  end
end

nested_circuit = Trailblazer::Circuit::Builder.Circuit(
  *((1..10).collect { |i| [i, node: MyNode[nil, MyAdapter]] })
)

circuit = Trailblazer::Circuit::Builder.Circuit(
  *((1..10).collect { |i| [i, node: MyNode[nested_circuit, MyProcessor]] })
)

circuit_node = MyNode[circuit, MyProcessor]

MyRunner.({}, {}, nil, MyRunner, circuit_node, nil)








module Call
  def call(ctx, flow_options, signal, runner, node, id) # DISCUSS: do we need the node here? => WrapRuntime?
    # could we not just call the task here with LibInterface?

    adapter.(task, ctx, flow_options, signal, **circuit_options) # DISCUSS: could we pass node_processor_options to Processor.() to set a differing start task?
  end
end










class MyNodeidAdapter
  def self.call(_, lib_ctx, flow_options, signal, runner, _)
    # with an adapter that doesn't do anything but extracting the node, we don't need tasks.
    return lib_ctx, flow_options, signal
  end
end

class MyNodeidNode < Trailblazer::Circuit::Node
  def call(lib_ctx, flow_options, signal, runner, circuit_tuple)
    adapter.(task, lib_ctx, flow_options, signal, runner, circuit_tuple)
  end
end

class MyNodeidProcessor
  # TODO: this can still be optimized for runtime speed, even though I spent days on it already.
  def self.call(circuit, lib_ctx, flow_options, signal, runner, node)
    start_tuple = circuit.start_tuple
    id, node = start_tuple

    loop do
      # puts ">>>Processor #{id.inspect} <<<#{signal.inspect}>>> #{node.class} #{lib_ctx[:target_ctx].to_h}"
      lib_ctx, flow_options, signal = runner.(
        lib_ctx,
        flow_options,
        signal,
        # **circuit_options,
        runner,
        node, # NOTE: you can access the current node in a task via the CircuitInterface.
      )

      id, node, signal = circuit.resolve(id, signal) # DISCUSS: pass id and node?

      return lib_ctx, flow_options, signal unless node
      # unless ()

        # raise_illegal_signal_error!(task, signal, @map[task], **circuit_options)
      # end
    end
  end
end

class MyNodeidRunner
  def self.call(lib_ctx, flow_options, signal, runner, node)
    node.(lib_ctx, flow_options, signal, runner, node)
  end
end

nested_circuit = Trailblazer::Circuit::Builder.Circuit(
  *((1..10).collect { |i| [i, node: MyNodeidNode[nil, MyNodeidAdapter]] })
)

circuit = Trailblazer::Circuit::Builder.Circuit(
  *((1..10).collect { |i| [i, node: MyNodeidNode[nested_circuit, MyNodeidProcessor]] })
)

tuple_circuit_node = MyNodeidNode[circuit, MyNodeidProcessor]

MyNodeidRunner.({}, {}, nil, MyNodeidRunner, tuple_circuit_node)







require "benchmark/ips"

Benchmark.ips do |x|
  x.report("cix") {
    Trailblazer::Circuit::Node::Runner.({}, {}, nil, node: old_circuit_node, runner: Trailblazer::Circuit::Node::Runner)
  }

  x.report("processor int") {
    MyRunner.({}, {}, nil, MyRunner, circuit_node, nil)
  }

  x.report("proc node-id") {
    MyNodeidRunner.({}, {}, nil, MyNodeidRunner, tuple_circuit_node)
  }

  x.compare!
end

# ==> passing the id as another posarg is not really slower!
#
# Calculating -------------------------------------
#                  cix     10.587k (± 2.1%) i/s   (94.45 μs/i) -     53.460k in   5.049492s
#        processor int     26.683k (± 1.5%) i/s   (37.48 μs/i) -    135.200k in   5.066813s
#         proc node-id     26.616k (± 2.3%) i/s   (37.57 μs/i) -    134.500k in   5.053381s

# Comparison:
# processor int:    26683.4 i/s
#  proc node-id:    26615.8 i/s - same-ish: difference falls within error
#           cix:    10587.2 i/s - 2.52x  slower


# The "tuple" version is actually slower! 1.2x

class MyTupleAdapter
  def self.call(_, lib_ctx, flow_options, signal, runner, _)
    # with an adapter that doesn't do anything but extracting the node, we don't need tasks.
    return lib_ctx, flow_options, signal
  end
end

class MyTupleNode < Trailblazer::Circuit::Node
  def call(lib_ctx, flow_options, signal, runner, circuit_tuple)
    adapter.(task, lib_ctx, flow_options, signal, runner, circuit_tuple)
  end
end

class MyTupleProcessor
  # TODO: this can still be optimized for runtime speed, even though I spent days on it already.
  def self.call(circuit, lib_ctx, flow_options, signal, runner, (node, id))
    start_tuple = circuit.start_tuple
    id, node = start_tuple

    loop do
      # puts ">>>Processor #{id.inspect} <<<#{signal.inspect}>>> #{node.class} #{lib_ctx[:target_ctx].to_h}"
      lib_ctx, flow_options, signal = runner.(
        lib_ctx,
        flow_options,
        signal,
        # **circuit_options,
        runner,
        [
          node, # NOTE: you can access the current node in a task via the CircuitInterface.
          id
        ],
      )

      id, node, signal = circuit.resolve(id, signal) # DISCUSS: pass id and node?

      return lib_ctx, flow_options, signal unless node
      # unless ()

        # raise_illegal_signal_error!(task, signal, @map[task], **circuit_options)
      # end
    end
  end
end

class MyTupleRunner
  def self.call(lib_ctx, flow_options, signal, runner, (node, id))
    node.(lib_ctx, flow_options, signal, runner, [node, id])
  end
end

nested_circuit = Trailblazer::Circuit::Builder.Circuit(
  *((1..10).collect { |i| [i, node: MyTupleNode[nil, MyTupleAdapter]] })
)

circuit = Trailblazer::Circuit::Builder.Circuit(
  *((1..10).collect { |i| [i, node: MyTupleNode[nested_circuit, MyTupleProcessor]] })
)

tuple_circuit_node = MyTupleNode[circuit, MyTupleProcessor]

MyTupleRunner.({}, {}, nil, MyTupleRunner, [tuple_circuit_node])
