require "test_helper"

class PipelineTest < Minitest::Spec
  class Task < Struct.new(:id, :return_signal)
    def call(lib_ctx, flow_options, signal, target_ctx:, **)
      target_ctx[:seq] << id

      return lib_ctx, flow_options, return_signal
    end
  end

  it "always uses {nil} as the lookup signal, regardless what was returned, but returns the actual last signal" do
    pipe = _A::Circuit::Builder.Pipeline(
      [:a, Task.new(:a, Object)],
      [:b, Task.new(:b, Right)],
      [:c, Task.new(:c, Module)],
    )

    assert_run pipe, terminus: Module, seq: [:a, :b, :c]
  end

  it "#eql?: Pipelines with the same order and nodes are ==" do
    my_original_pipe = Pipeline([:a, :a], [:b, :b])

    my_other_pipe = Pipeline([:b, :b])
    my_other_pipe = Trailblazer::Circuit::Adds.(
      my_other_pipe,
      [:a, Trailblazer::Circuit::Node[:a, Trailblazer::Circuit::Task::Adapter::LibInterface], :before, :b]
    )

    assert_equal my_original_pipe, my_other_pipe
  end
end
