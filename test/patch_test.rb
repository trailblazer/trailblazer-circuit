require "test_helper"

class PatchTest < Minitest::Spec
  let(:my_exec_context) { T.def_tasks(:a, :b, :c, :d, :e, success_signal: nil) }

  it "what" do
    my_pipe = Trailblazer::Circuit::Builder.Pipeline(
      [:a, my_exec_context.method(:a)],
      [:b, my_exec_context.method(:b)],
    )

    my_outer_pipe = Trailblazer::Circuit::Builder.Pipeline(
      [:c, my_exec_context.method(:c)],
      [:ab, my_pipe, Trailblazer::Circuit::Processor],
    )

    my_top_node = Trailblazer::Circuit.Builder(
      [:d, my_exec_context.method(:d)],
      [:abc, my_outer_pipe, Trailblazer::Circuit::Processor],
    )

    # patch on the top pipe itself.
    my_new_top_node = Trailblazer::Circuit::Node::Patch.(
      my_top_node,
      [],
      adds: [
        [
          :e,
          Trailblazer::Circuit::Node[my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface], # TODO: provide shortcut from Builder.
          :replace, :d
        ]
      ]
    )

    # patch two levels down.
    node_two_levels_patched = Trailblazer::Circuit::Node::Patch.(
      my_top_node,
      [:abc],
      adds: [
        [
          :e,
          Trailblazer::Circuit::Node[my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface],
          :after, :c
        ]
      ]
    )

    # patch three levels down.
    node_three_levels_patched = Trailblazer::Circuit::Node::Patch.(
      my_top_node,
      [:abc, :ab],
      adds: [
        [
          :e,
          Trailblazer::Circuit::Node[my_exec_context.method(:e), Trailblazer::Circuit::Task::Adapter::LibInterface],
          :after, :a
        ]
      ]
    )

    assert_run node: my_top_node, seq: [:d, :c, :a, :b]
    assert_run node: my_new_top_node, seq: [:e, :c, :a, :b]
    assert_run node: node_two_levels_patched, seq: [:d, :c, :e, :a, :b]
    assert_run node: node_three_levels_patched, seq: [:d, :c, :a, :e, :b]
  end

  it "with something like Topology, we can hop over several ID segments" do
    my_exec_context = T.def_tasks(:a, :b, :c, :d, :e, :f, :tw_confirm, success_signal: nil)

    # this is callled after every path segment iteration in Patch.
    def my_adds_implementation_for_topology(topology, *adds)
      # puts "topology patch #{topology}"
      # raise 'how do we get the user alteration only in the leaf of the patch?'

      id, node, action, target = adds[0]

      tw_id, op_id = id

      if op_id #
        tw = topology.nodes.fetch(tw_id)#.task.nodes.fetch(op_id)

        tw = Trailblazer::Circuit::Adds.(tw.task, [op_id, node, action, op_id])

        id = tw_id
        node = Trailblazer::Circuit::Node[tw, Trailblazer::Circuit::Processor]
        target = tw_id
      end

      # normally, we'd do step ..., replace: target here
      new_circuit = Trailblazer::Circuit::Adds.(topology.circuit, [id, node, action, target])
      # pp new_circuit

      topology.class.new(new_circuit)
    end

    my_topology_class = Struct.new(:circuit) do
      def nodes
        circuit.nodes
      end

      # Acts-as-circuit
      def start_tuple
        circuit.start_tuple
      end
      def resolve(*args)
        circuit.resolve(*args)
      end
    end

    my_adds_processor = method(:my_adds_implementation_for_topology)


    _, my_pipe = T.pipe(nil, # task_wrap
      :a,
      [:Create, my_topology_class.new(
        T.pipe(:_Create, # call_task
          :tw_b,
          T.pipe(:tw_Validate, # task_wrap
            :in,
            [:Validate, my_topology_class.new(
              T.pipe(:_Validate, # call_task
                :tw_e,
                T.pipe(:tw_verify,
                  :f, # call_task
                  :out,
                )
              )[1]
            ), options: {adds: my_adds_processor}]
          ),
        )[1],
      ), options: {adds: my_adds_processor}]
    )

      # we traverse through the Activity and retrieve a particular nested thing (like :tw_Validate and :tw_verify), change that,
    # and then let the traversed Activity recompute from its "top" level.
    # this implies knowledge about the Activity's altering interface.
    my_segments = [:Create, [:tw_Validate, :Validate]]



    my_top_node = Trailblazer::Circuit::Node[my_pipe, Trailblazer::Circuit::Processor]

    my_patched_topology_node = Trailblazer::Circuit::Node::Patch.(
      my_top_node,
      my_segments,
      adds: [
        [
          :tw_confirm,
          Trailblazer::Circuit::Node[my_exec_context.method(:tw_confirm), Trailblazer::Circuit::Task::Adapter::LibInterface],
          :before, :tw_verify
        ]
      ]
    )

    assert_equal my_patched_topology_node.task.nodes.fetch(:Create).task.is_a?(my_topology_class), true

    assert_run node: my_top_node, seq: [:a, :tw_b, :in, :tw_e, :f, :out], terminus: Object
    assert_run node: my_patched_topology_node, seq: [:a, :tw_b, :in, :tw_e, :tw_confirm, :f, :out], terminus: Object
  end
end
