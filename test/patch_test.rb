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

  it "with something like Topology, we can hop over several ID segments
via :processor_for_adds we can configure how the changes are applied to the current task.
in this example, we only iterate from Topology to Topology. in the dsl gem, this approach is used.
this tests {Patch.()}'s {:processor_for_adds} option.
" do
    def my_adds_implementation_for_topology(topology, *adds)
      id, node, action, target = adds[0]

      tw_id, op_id = id

      # we're mimicking the structure of a DSL Topology where a "step" is
      #
      #   tw
      #   |-- call_task
      #
      # that's why we have to do two hops of Adds.(). The real Topology does that
      # in #step, too.
      if op_id
        tw = topology.nodes.fetch(tw_id)

        tw = Trailblazer::Circuit::Adds.(tw.task, [op_id, node, action, op_id])

        id = tw_id
        node = Trailblazer::Circuit::Node[tw, Trailblazer::Circuit::Processor]
        target = tw_id
      end

      # normally, we'd do step ..., replace: target here
      new_circuit = Trailblazer::Circuit::Adds.(topology.circuit, [id, node, action, target])

      topology.class.new(new_circuit)
    end

    my_topology_class = Struct.new(:circuit) do
      def nodes = circuit.nodes
      # Acts-as-circuit
      def start_tuple = circuit.start_tuple
      def resolve(*args) = circuit.resolve(*args)
    end

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
            )]
          ),
        )[1],
      )]
    )

    my_top_topology = my_topology_class.new(my_pipe)
    my_top_node = Trailblazer::Circuit::Node[my_top_topology, Trailblazer::Circuit::Processor]

      # we traverse through the Activity and retrieve a particular nested thing (like :tw_Validate and :tw_verify), change that,
    # and then let the traversed Activity recompute from its "top" level.
    # this implies knowledge about the Activity's altering interface.
    my_segments = [:Create, [:tw_Validate, :Validate]]

    my_patched_topology_node = Trailblazer::Circuit::Node::Patch.(
      my_top_node,
      my_segments,
      adds: [
        [
          :tw_confirm,
          Trailblazer::Circuit::Node[T.def_task(:tw_confirm, success_signal: nil), Trailblazer::Circuit::Task::Adapter::LibInterface],
          :before, :tw_verify
        ]
      ],
      processor_for_adds: method(:my_adds_implementation_for_topology)
    )

    assert_equal my_patched_topology_node.task.nodes.fetch(:Create).task.is_a?(my_topology_class), true

    assert_run node: my_top_node, seq: [:a, :tw_b, :in, :tw_e, :f, :out], terminus: Object
    assert_run node: my_patched_topology_node, seq: [:a, :tw_b, :in, :tw_e, :tw_confirm, :f, :out], terminus: Object
  end
end
