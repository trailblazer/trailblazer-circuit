require "test_helper"

class CircuitTest < Minitest::Spec
  let(:my_exec_context) { T.def_tasks(:a, :b, :c, success_signal: nil) }
  let(:my_nodes) do
    {
      a: node_a = Trailblazer::Circuit::Node[:a, my_exec_context.method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface],
      b: Trailblazer::Circuit::Node[:b, my_exec_context.method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],
      c: Trailblazer::Circuit::Node[:c, my_exec_context.method(:c), Trailblazer::Circuit::Task::Adapter::LibInterface],
    }
  end

  let(:my_flow_map) do
    {
      a: {nil => :b},
      b: {nil => :c},
      c: {nil => nil},
    }
  end

  it "{.build} computes start" do
    circuit = Trailblazer::Circuit.build(nodes: my_nodes, flow_map: my_flow_map)

    assert_equal circuit.start_tuple, [:a, my_nodes[:a]]

    assert_run circuit, seq: [:a, :b, :c]
  end

  it "{#new} allows setting start manually" do
    my_flow_map = {
      a: {nil => :b},
      b: {nil => :c},
      c: {nil => nil}
    }

    circuit = Trailblazer::Circuit.new(
      my_flow_map,
      [:b, my_nodes[:b]],
      my_nodes,
    )

    assert_equal circuit.start_tuple, [:b, my_nodes[:b]]

    assert_run circuit, seq: [:b, :c]
  end

  it "exposes {#start_tuple} used in {Processor} and {#nodes} and {#flow_map}" do
    circuit = Trailblazer::Circuit.new(
      my_flow_map,
      [:b, my_nodes[:b]],
      my_nodes,
    )

    assert_equal circuit.start_tuple, [:b, my_nodes[:b]]
    assert_equal circuit.nodes, my_nodes
    assert_equal circuit.flow_map, my_flow_map
  end

  it "a Circuit doesn't have explicit termini set, if a signal points to {nil}, it terminates" do
    my_flow_map = {
      a: {nil => [:b, nil]},
      b: {nil => [:c, nil], :Left => [nil, :Left]}, # the :Left signal points to nil, meaning it terminates here.
      c: {nil => [nil, nil]} # signal from  terminus pointing to nil terminates.
    }

    circuit = Trailblazer::Circuit.build(
      flow_map: my_flow_map,
      nodes: my_nodes,
    )

    assert_run circuit, seq: [:a, :b, :c]
    assert_run circuit, seq: [:a, :b], target_ctx: {seq: [], b: :Left}, terminus: :Left
  end

  it "should raise with IllegalSignalError (# TODO)" do
    my_flow_map = {
      a: {nil => :b}, # we don't know {"unknown signal"} here.
    }

    circuit = Trailblazer::Circuit.build(
      flow_map: my_flow_map,
      nodes: my_nodes,
    )

    exception = assert_raises KeyError do
      assert_run circuit, seq: [:a],
        target_ctx: {a: "unknown signal", seq: []}
    end

    assert_equal exception.message, "key not found: \"unknown signal\""
  end
end

class CircuitScopeTest < Minitest::Spec
  it "obviously allows scoping its elements" do
    circuit = _A::Circuit::Builder.Circuit(
      [:a, Capture.new(:a), scoped: true, connections: {nil => :b, Left => :c}], # isolated.
      [:b, Capture.new(:b), merge_to_lib_ctx: {d: 4}, scoped: true, copy_to_outer_ctx: [:d], connections: {nil => :c, Left => :c}],
      [:c, Capture.new(:c), scoped: true, connections: {nil => nil}], # isolated, but sees {:d}.
    )

    lib_ctx, flow_options = assert_run circuit, terminus: nil, seq: []

    assert_equal flow_options, {
      :a=> a = [ctx={:target_ctx=>{:seq=>[]}}, {}, nil, ctx],
      :b=> b = [{:target_ctx=>{:seq=>[]}, :d=>4}, {a: a}, nil, {**ctx, :d=>4}],
      :c=> c = [{:target_ctx=>{:seq=>[]}, :d=>4}, {a: a, b: b}, nil, {**ctx, :d=>4}],
    }

    assert_equal lib_ctx, {:target_ctx=>{:seq=>[]}, :d=>4}
  end

  it "internally set variables can be exposed to the follower via {:copy_to_outer_ctx}" do
    circuit = _A::Circuit::Builder.Circuit(
      [:a, Capture.new(:a, pollute: true), scoped: true, copy_to_outer_ctx: [:pollute], connections: {nil => :b, Left => :b}],
      [:b, Capture.new(:b), scoped: true, connections: {nil => nil}],  # sees :pollute
    )

    lib_ctx, flow_options = assert_run circuit, terminus: nil, seq: []
    assert_equal flow_options, {
      :a=> a = [ctx={:target_ctx=>{:seq=>[]}}, {}, nil, ctx],
      :b=> b = [{**ctx, :pollute=>true}, {a: a}, nil, {**ctx, :pollute=>true}],
    }
    assert_equal lib_ctx, {target_ctx: {seq: []}, pollute: true}
  end

  it "allows discarding the internal signal and return the outer signal with {:return_outer_signal}" do

  end
end

class CircuitResolveTest < Minitest::Spec
  it "{Circuit#resolve} returns the next node and the signal" do
    def self.a(lib_ctx, flow_options, signal, **)
      lib_ctx[:seq_in_lib_ctx] << :a
      return lib_ctx, flow_options, signal
    end
    def self.b(lib_ctx, flow_options, signal, **)
      lib_ctx[:seq_in_lib_ctx] << :b
      return lib_ctx, flow_options, signal
    end

    my_nodes = {
      a: Trailblazer::Circuit::Node[:a, method(:a), Trailblazer::Circuit::Task::Adapter::LibInterface],
      b: Trailblazer::Circuit::Node[:b, method(:b), Trailblazer::Circuit::Task::Adapter::LibInterface],
    }

    my_flow_map = {a: Trailblazer::Circuit::Resolver::Fixed.new(:b), b: Trailblazer::Circuit::Resolver::Fixed.new(nil)}

    my_circuit = Class.new(Trailblazer::Circuit) do
      def resolve(current_node_id, signal)
        signal += [current_node_id] # the signal emitted by current_node.

        super
      end
    end.build(flow_map:  my_flow_map, nodes: my_nodes)

    lib_ctx, _ = assert_run my_circuit, seq: [], seq_in_lib_ctx: [], signal: [].freeze, terminus: [:a, :b]

    assert_equal lib_ctx, {seq_in_lib_ctx: [:a, :b], target_ctx: {seq: []}}
  end

  # it's now possible to either use a "hardcore" signal mapping hash, but it IS also possible
  # to route without caring about the signal, etc.
  it "is possible to use a different resolving hash per node" do
    my_flow_map = {
      a: {Right => [:b, Right], Left => [:failure, Left]}, # normal Trailblazer::Circuit::Resolver from a circuit step.
      b: Trailblazer::Circuit::Resolver::Fixed.new(:c), # like {<any> => :next_step}
      c: Trailblazer::Circuit::Resolver::Fixed.new(nil), # terminate, but return the "original" signal.
      failure: {Right => [nil, Right]}
    }

    my_exec_context = T.def_tasks(:a, :b, :c, :failure, success_signal: Right)

    my_nodes = {
      a: Trailblazer::Circuit::Node[:a, :a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      b: Trailblazer::Circuit::Node[:b, :b, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      c: Trailblazer::Circuit::Node[:c, :c, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      failure: Trailblazer::Circuit::Node[:failure, :failure, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
    }

    my_circuit = Trailblazer::Circuit.build(flow_map: my_flow_map, nodes: my_nodes)

    assert_run my_circuit, terminus: Right, seq: [:a, :b, :c], circuit_options: {exec_context: my_exec_context}
    assert_run my_circuit, terminus: Right, seq: [:a, :failure], circuit_options: {exec_context: my_exec_context}, target_ctx: {seq: [], a: Left}

    # With a Reolver::Fixed, a terminating node can return any signal, but still terminates.
    assert_run my_circuit, terminus: :c_says_Right, seq: [:a, :b, :c], circuit_options: {exec_context: my_exec_context}, target_ctx: {seq: [], c: :c_says_Right}
  end

  it "by using a custom Resolver, we can implement (fast?) value-on-signal circuits" do
    my_value_on_signal_resolver = Struct.new(:signals_to_next) do
      def fetch(signal)
        decision, signal = signal

        return signals_to_next.fetch(decision), signal
      end
    end.new({Right => :d, Left => :e})

    my_exec_context = Struct.new(:name) do
      def call(lib_ctx, flow_options, signal, **)
        signal += [name]

        return lib_ctx, flow_options, signal
      end
    end

    my_decider = ->(lib_ctx, flow_options, signal, decision_signal:, **) do
      signal += [:my_decider]

      return lib_ctx, flow_options, [decision_signal, signal]
    end

    lib_interface = Trailblazer::Circuit::Task::Adapter::LibInterface

    # as a "representative benchmark circuit", i use something like a VariableMapping:::Conditional, a mix of pipe and decider.
    my_circuit = Trailblazer::Circuit::Builder.Circuit(
      [:a, my_exec_context.new(:a), lib_interface, connections: Trailblazer::Circuit::Resolver::Fixed.new(:b)],
      [:b, my_exec_context.new(:b), lib_interface, connections: Trailblazer::Circuit::Resolver::Fixed.new(:c)],
      [:c, my_decider, lib_interface, connections: my_value_on_signal_resolver],
      [:d, my_exec_context.new(:d), lib_interface, connections: Trailblazer::Circuit::Resolver::Fixed.new(:f)],
      [:e, my_exec_context.new(:e), lib_interface, connections: Trailblazer::Circuit::Resolver::Fixed.new(nil)],
      [:f, my_exec_context.new(:f), lib_interface, connections: Trailblazer::Circuit::Resolver::Fixed.new(nil)],
    )
    node_value_on_signal = Trailblazer::Circuit::Node[:id, my_circuit, Trailblazer::Circuit::Processor] # FIXME: make it a Scoped node that returns the original signal.

    assert_run node_value_on_signal, node: true, terminus: [:a, :b, :my_decider, :d, :f], seq: [], decision_signal: Right, signal: []
    assert_run node_value_on_signal, node: true, terminus: [:a, :b, :my_decider, :e], seq: [], decision_signal: Left, signal: []

=begin
    #
    # benchmarking time
    #
    my_exec_context_writing_to_lib_ctx = Struct.new(:name) do
      def call(lib_ctx, flow_options, signal, seq_:, **)
        lib_ctx = lib_ctx.merge(seq_: seq_ += [name])

        return lib_ctx, flow_options, signal
      end
    end

    my_decider_writing_to_lib_ctx = ->(lib_ctx, flow_options, signal, seq_:, decision_signal:, **) do
      lib_ctx = lib_ctx.merge(seq_: seq_ += [:my_decider])

      return lib_ctx, flow_options, decision_signal
    end

    my_circuit_writing_to_lib_ctx = Trailblazer::Circuit::Builder.Circuit(
      [:a, my_exec_context_writing_to_lib_ctx.new(:a), lib_interface, connections: Trailblazer::Circuit::Resolver::Fixed.new(:b)],
      [:b, my_exec_context_writing_to_lib_ctx.new(:b), lib_interface, connections: Trailblazer::Circuit::Resolver::Fixed.new(:c)],
      [:c, my_decider_writing_to_lib_ctx, lib_interface, connections: {Right => [:d, Right], Left => [:e, Left]}],
      [:d, my_exec_context_writing_to_lib_ctx.new(:d), lib_interface, connections: Trailblazer::Circuit::Resolver::Fixed.new(:f)],
      [:e, my_exec_context_writing_to_lib_ctx.new(:e), lib_interface, connections: Trailblazer::Circuit::Resolver::Fixed.new(nil)],
      [:f, my_exec_context_writing_to_lib_ctx.new(:f), lib_interface, connections: Trailblazer::Circuit::Resolver::Fixed.new(nil)],
    )

    node_writing_to_lib_ctx = Trailblazer::Circuit::Node::Scoped[:id, my_circuit_writing_to_lib_ctx, Trailblazer::Circuit::Processor]

    lib_ctx, flow_options, signal = assert_run node_writing_to_lib_ctx, node: true, terminus: Right, seq: [], decision_signal: Right, signal: [], seq_: []
    # assert_equal lib_ctx[:seq_], [:a, :b, :my_decider, :d, :f]

    lib_ctx, flow_options, signal = assert_run node_writing_to_lib_ctx, node: true, terminus: Left, seq: [], decision_signal: Left, signal: [], seq_: []
    # assert_equal lib_ctx[:seq_], [:a, :b, :my_decider, :e]
    require "benchmark/ips"

    Benchmark.ips do |x|
      x.report("lib_ctx") {
        Benchmark.run_node(node_writing_to_lib_ctx, lib_ctx: {seq_: [], decision_signal: Right})
      }

      bla_terminus = [:a, :b, :my_decider, :d, :f]

      x.report("value-on-signal") {
        Benchmark.run_node(node_value_on_signal, lib_ctx: {decision_signal: Right}, signal: [])
      }

      x.compare!

     #  Comparison:
     # value-on-signal:   156511.5 i/s
     #         lib_ctx:   116748.2 i/s - 1.34x  slower
    end
=end
  end
end
