require "test_helper"
require "benchmark/ips"

class MyOldAdapter
  def self.call(task, lib_ctx, flow_options, signal, **circuit_options)
    # with an adapter that doesn't do anything but extracting the node, we don't need tasks.
    return task.(lib_ctx, flow_options, signal, **lib_ctx) # let's be fair here and simply call the lib task, no lib kwargs!
    # return lib_ctx, flow_options, signal
  end
end

# raise "benchmark with kwargs being passed to the task! "

class MyOldTask
  def self.call(lib_ctx, flow_options, signal, **)
    return lib_ctx, flow_options, signal
  end
end

old_nested_circuit = Trailblazer::Circuit::Builder.Circuit(
  *((1..10).collect { |i| [i, MyOldTask, MyOldAdapter] })
)

old_circuit_node = Trailblazer::Circuit.Builder(
  *((1..10).collect { |i| [i, old_nested_circuit, Trailblazer::Circuit::Processor] })
)

Trailblazer::Circuit::Node::Runner.({}, {}, nil, node: old_circuit_node, runner: Trailblazer::Circuit::Node::Runner)


#
# this implementation always uses Adapter
#
class MyAdapter
  def self.call(task, lib_ctx, flow_options, signal)
    # with an adapter that doesn't do anything but extracting the node, we don't need tasks.
    return task.(lib_ctx, flow_options, signal, **lib_ctx)
  end
end

class MyNode < Trailblazer::Circuit::Node
  def call(lib_ctx, flow_options, signal)
    adapter.(task, lib_ctx, flow_options, signal)
  end
end

class MyProcessor
  # TODO: this can still be optimized for runtime speed, even though I spent days on it already.
  def self.call(circuit, lib_ctx, flow_options, signal)
    id, node = circuit.start_tuple # DISCUSS: this could also be done in the "Adapter", and the Processor could be the tas

    loop do
      # puts ">>>Processor #{id.inspect} <<<#{signal.inspect}>>> #{node.class} #{lib_ctx[:target_ctx].to_h}"
      lib_ctx, flow_options, signal = flow_options.(
        lib_ctx,
        flow_options,
        signal,
        # **circuit_options,
        # runner,
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
  def self.call(lib_ctx, flow_options, signal, node, id)
    node.(lib_ctx, flow_options, signal)
  end
end

nested_circuit = Trailblazer::Circuit::Builder.Circuit(
  *((1..10).collect { |i| [i, node: MyNode[MyOldTask, MyAdapter]] })
)

circuit = Trailblazer::Circuit::Builder.Circuit(
  *((1..10).collect { |i| [i, node: MyNode[nested_circuit, MyProcessor]] })
)

circuit_node = MyNode[circuit, MyProcessor]

MyRunner.({}, MyRunner, nil, circuit_node, nil)


# module Call
#   def call(ctx, flow_options, signal, runner, node, id) # DISCUSS: do we need the node here? => WrapRuntime?
#     # could we not just call the task here with LibInterface?

#     adapter.(task, ctx, flow_options, signal, **circuit_options) # DISCUSS: could we pass node_processor_options to Processor.() to set a differing start task?
#   end
# end









#
# this implementation: Node calls task directly, bypassing adapter.
# we don't use kwargs here at all, which is a bit unfair on the kwargs implementations.
#
# class MyTripleTask
#   def self.call(lib_ctx, flow_options, signal, **)
#     # with an adapter that doesn't do anything but extracting the node, we don't need tasks.
#     return lib_ctx, flow_options, signal
#   end
# end

class MyTripleNode < Struct.new(:task) #Trailblazer::Circuit::Node
  def call(lib_ctx, flow_options, signal)
    # the idea here is that we call a task, and it could be a Circuit, an Adapter, or the task directly. that way, we save the Adapter.
    task.(lib_ctx, flow_options, signal, **lib_ctx)
  end
end

class MyTripleProcessor < Struct.new(:circuit)
  # TODO: this can still be optimized for runtime speed, even though I spent days on it already.
  def call(lib_ctx, flow_options, signal, **) # FIXME: what if we need the node/id here? for an exception?
    id, node = circuit.start_tuple # DISCUSS: this could also be done in the "Adapter", and the Processor could be the tas

    loop do
      # puts ">>>Processor #{id.inspect} <<<#{signal.inspect}>>> #{node.class} #{lib_ctx[:target_ctx].to_h}"
      lib_ctx, flow_options, signal = flow_options.(
        lib_ctx,
        flow_options,
        signal,
        # **circuit_options,
        # runner,
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

class MyTripleRunner
  def self.call(lib_ctx, flow_options, signal, node, id)
    # node.(lib_ctx, flow_options, signal, node, id)
    node.(lib_ctx, flow_options, signal)
  end
end

nested_circuit = Trailblazer::Circuit::Builder.Circuit(
  *((1..10).collect { |i| [i, node: MyTripleNode[MyOldTask]] })
)

circuit = Trailblazer::Circuit::Builder.Circuit(
  # *((1..10).collect { |i| [i, node: MyTripleNode[MyTripleProcessor.new(nested_circuit)]] })
  *((1..10).collect { |i| [i, node: MyTripleNode[MyTripleProcessor.new(nested_circuit)]] })
)

triple_circuit_node = MyTripleNode[MyTripleProcessor.new(circuit)]

# MyTripleRunner.({}, {runner: MyTripleRunner}, nil, triple_circuit_node, nil)
MyTripleRunner.({}, MyTripleRunner, nil, triple_circuit_node, nil)







# #
# # this implementation: Node calls task directly with kwargs, bypassing adapter.
# #
# class MyTripleKwargsTask
#   def self.call(lib_ctx, flow_options, signal, **)
#     # with an adapter that doesn't do anything but extracting the node, we don't need tasks.
#     return lib_ctx, flow_options, signal
#   end
# end

# class MyTripleKwargsNode < Struct.new(:task) #Trailblazer::Circuit::Node
#   def call(lib_ctx, flow_options, signal)
#     task.(lib_ctx, flow_options, signal, **lib_ctx)
#   end
# end

# class MyTripleKwargsProcessor < Struct.new(:circuit)
#   # TODO: this can still be optimized for runtime speed, even though I spent days on it already.
#   def call(lib_ctx, flow_options, signal, **) # FIXME: what if we need the node/id here? for an exception?
#     id, node = circuit.start_tuple # DISCUSS: this could also be done in the "Adapter", and the Processor could be the tas

#     loop do
#       # puts ">>>Processor #{id.inspect} <<<#{signal.inspect}>>> #{node.class} #{lib_ctx[:target_ctx].to_h}"
#       lib_ctx, flow_options, signal = flow_options.(
#         lib_ctx,
#         flow_options,
#         signal,
#         # **circuit_options,
#         # runner,
#         node, # NOTE: you can access the current node in a task via the CircuitInterface.
#         id,
#       )

#       id, node, signal = circuit.resolve(id, signal) # DISCUSS: pass id and node?

#       return lib_ctx, flow_options, signal unless node
#       # unless ()

#         # raise_illegal_signal_error!(task, signal, @map[task], **circuit_options)
#       # end
#     end
#   end
# end


# nested_circuit = Trailblazer::Circuit::Builder.Circuit(
#   *((1..10).collect { |i| [i, node: MyTripleKwargsNode[MyOldTask]] })
# )

# circuit = Trailblazer::Circuit::Builder.Circuit(
#   # *((1..10).collect { |i| [i, node: MyTripleKwargsNode[MyTripleKwargsProcessor.new(nested_circuit)]] })
#   *((1..10).collect { |i| [i, node: MyTripleKwargsNode[MyTripleKwargsProcessor.new(nested_circuit)]] })
# )

# triple_kwargs_circuit_node = MyTripleKwargsNode[MyTripleKwargsProcessor.new(circuit)]

# # MyTripleKwargsRunner.({}, {runner: MyTripleKwargsRunner}, nil, triple_kwargs_circuit_node, nil)
# my_triple_kwargs_ctx = {exec_context: Module, value: 1}
# MyTripleRunner.(my_triple_kwargs_ctx, MyTripleRunner, nil, triple_kwargs_circuit_node, nil)





lib_ctx = {target_ctx: {params: {}}, exec_context: 1}

require "benchmark/ips"

Benchmark.ips do |x|
  x.report("cix") {
    Trailblazer::Circuit::Node::Runner.(lib_ctx, {}, nil, node: old_circuit_node, runner: Trailblazer::Circuit::Node::Runner)
  }

  x.report("processor int") {
    MyRunner.(lib_ctx, MyRunner, nil, circuit_node, nil)
  }

  x.report("proce triple") {
    MyTripleRunner.(lib_ctx, MyTripleRunner, nil, triple_circuit_node, nil)
  }

  # x.report("triple kwargs") {
  #   MyTripleRunner.(my_triple_kwargs_ctx, MyTripleRunner, nil, triple_kwargs_circuit_node, nil)
  # }


  x.compare!
end


# obviously, leaving out the Adapter save 0.06x speed.
# Comparison:
#  proce triple:    28419.7 i/s
# processor int:    26883.5 i/s - 1.06x  slower
#           cix:    12464.7 i/s - 2.28x  slower



# (with processor int using flow_options as runner)
# Comparison:
#  proce triple:    30920.9 i/s
# processor int:    28670.0 i/s - 1.08x  slower
# triple kwargs:    28253.0 i/s - 1.09x  slower
#           cix:    12832.2 i/s - 2.41x  slower



# Comparison: (before making {processor int} implementation do not pass node, id further down)
#  proce triple:    29568.1 i/s
# triple kwargs:    27533.3 i/s - 1.07x  slower
# processor int:    27161.8 i/s - 1.09x  slower
#           cix:    12368.9 i/s - 2.39x  slower



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
