require "test_helper"

class PipelineTest < Minitest::Spec
  class Task < Struct.new(:id, :return_signal)
    def call(lib_ctx, flow_options, signal, **)
      flow_options[:application_ctx][:seq] << id

      return lib_ctx, flow_options, return_signal
    end
  end

  it "always uses {nil} as the lookup signal, regardless what was returned, but returns the actual last signal" do
    pipe = _A::Circuit::Builder.Pipeline(
      [:a, Task.new(:a, Object), _A::Circuit::Task::Adapter::LibInterface],
      [:b, Task.new(:b, Right), _A::Circuit::Task::Adapter::LibInterface],
      [:c, Task.new(:c, Module), _A::Circuit::Task::Adapter::LibInterface],
    )

    assert_run pipe, terminus: Module, seq: [:a, :b, :c]
  end

  it "obviously allows scoping its elements" do
    pipe = _A::Circuit::Builder.Pipeline(
      [:a, Capture.new(:a), _A::Circuit::Task::Adapter::LibInterface, {}, _A::Circuit::Node::Scoped], # isolated.
      [:b, Capture.new(:b), _A::Circuit::Task::Adapter::LibInterface, {}, _A::Circuit::Node::Scoped, copy_to_outer_ctx: [:d], merge_to_lib_ctx: {d: 4}],
      [:c, Capture.new(:c), _A::Circuit::Task::Adapter::LibInterface, {}, _A::Circuit::Node::Scoped], # isolated, but sees {:d}.
    )

    lib_ctx, flow_options = assert_run pipe, terminus: nil, seq: []
    assert_equal flow_options, {
      application_ctx: {:seq=>[]},

      :a=> a = [{}, {:application_ctx=>{:seq=>[]}}, nil, {}],
      :b=> b = [{:d=>4}, {:application_ctx=>{:seq=>[]}, a: a}, nil, {:d=>4}],
      :c=> c = [{:d=>4}, {:application_ctx=>{:seq=>[]}, a: a, b: b}, nil, {:d=>4}],
    }
  end

  it "internally set variables can be exposed to the follower via :copy_to_outer_ctx" do
    pipe = _A::Circuit::Builder.Pipeline(
      [:a, Capture.new(:a, pollute: true), _A::Circuit::Task::Adapter::LibInterface, {}, _A::Circuit::Node::Scoped, copy_to_outer_ctx: [:pollute]],
      [:b, Capture.new(:b), _A::Circuit::Task::Adapter::LibInterface, {}, _A::Circuit::Node::Scoped, ],  # sees :pollute
    )

    lib_ctx, flow_options = assert_run pipe, terminus: nil, seq: []
    assert_equal flow_options, {
      application_ctx: {:seq=>[]},

      :a=> a = [{}, {:application_ctx=>{:seq=>[]}}, nil, {}],
      :b=> b = [{:pollute=>true}, {:application_ctx=>{:seq=>[]}, a: a}, nil, {:pollute=>true}],
    }
  end

  it "#eql?: Pipelines with the same order and nodes are ==" do
    my_original_pipe = Pipeline([:a, :a], [:b, :b])

    my_other_pipe = Pipeline([:b, :b])
    my_other_pipe = Trailblazer::Circuit::Adds.(my_other_pipe,
      [Trailblazer::Circuit::Node[id: :a, task: :a, interface: Trailblazer::Circuit::Task::Adapter::LibInterface::InstanceMethod], :before, :b]
    )

    assert_equal my_original_pipe, my_other_pipe
  end
end
