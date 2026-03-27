require "test_helper"

class EachTest < Minitest::Spec
  # Test that we can build something like the Each() macro,
# where we dynamically iterate over a dataset, as if it was a circuit 1 --> 2 --> 3].
  def my_task_a(lib_ctx, flow_options, signal, value:, index:, **)
    ctx = flow_options.fetch(:application_ctx)

    ctx[:seq] << [index, value]

    return lib_ctx, flow_options, signal
  end

  class MyEach
    def self.init(lib_ctx, flow_options, signal, **)
      ctx = flow_options.fetch(:application_ctx)
      dataset = ctx.fetch(:dataset)

      return lib_ctx.merge(
        enumerator: dataset.each_with_index,
      ), flow_options, signal
    end

    def self.fetch_value_from_dataset(lib_ctx, flow_options, signal, enumerator:, **)
      value, index = enumerator.next

      return lib_ctx.merge(value: value, index: index), flow_options, signal

    rescue StopIteration
      # DISCUSS: is there any other way to detect when an enumerator reached the end?
      return lib_ctx, flow_options, "done"
    end
  end

  it do
    nodes = {
      init: Trailblazer::Circuit::Node[:init, :init, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      fetch_value_from_dataset: Trailblazer::Circuit::Node[:fetch_value_from_dataset, :fetch_value_from_dataset, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
      a: Trailblazer::Circuit::Node::Scoped[:a, :my_task_a, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod, merge_to_lib_ctx: {exec_context: self}],
      finished: Trailblazer::Circuit::Node[:finished, :finished, Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod],
    }

    map = {
        init: {nil => :fetch_value_from_dataset},
        fetch_value_from_dataset: {nil => :a, "done" => nil},
        a: {nil => :fetch_value_from_dataset},
        finished: {}
      }

    circuit = Trailblazer::Circuit.build(flow_map: map, nodes: nodes)

    assert_run circuit, exec_context: MyEach, application_ctx: {dataset: [1,2,3]},
      seq: [[0, 1], [1, 2], [2, 3]],
      terminus: "done"
  end
end
