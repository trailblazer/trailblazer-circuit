require "test_helper"

class WrapRuntimeExtensionTest < Minitest::Spec
  it "via Extension::Set, the Extension#call receives the node_attrs" do
    my_ext_1 = Class.new(Trailblazer::Circuit::WrapRuntime::Extension) do
      def call(my_capture:, **node_attrs)
        my_capture = my_capture.merge(my_ext_1: node_attrs)

        return node_attrs.merge(my_capture: my_capture, my_ext_1: true)
      end
    end.new

    my_ext_2 = Class.new(Trailblazer::Circuit::WrapRuntime::Extension) do
      def call(my_capture:, **node_attrs)
        my_capture = my_capture.merge(my_ext_2: node_attrs)

        return node_attrs.merge(my_capture: my_capture, my_ext_2: true)
      end
    end.new

    my_set = Trailblazer::Circuit::WrapRuntime::Extension::Set.new([my_ext_1, my_ext_2])

    new_node_attrs = my_set.(task: Object, id: :node, my_capture: {})

    assert_equal new_node_attrs, {
      :task=>Object, :id=>:node, :my_ext_1=>true, :my_capture=>{:my_ext_1=>{:task=>Object, :id=>:node}, :my_ext_2=>{:task=>Object, :id=>:node, :my_ext_1=>true}}, :my_ext_2=>true
    }
  end

  it "Extension::AddsInstruction applies changes to the passed node's circuit" do
    my_adds_ext = ->(id:, **) {
      [
        [Trailblazer::Circuit::Node[id: :b, task: :b, interface: Module], :after, :a]
      ]
    }

    my_adds_instructions_ext = Trailblazer::Circuit::WrapRuntime.Extension(adds: my_adds_ext) # this is run by WrapRuntime::Runner

    my_set = Trailblazer::Circuit::WrapRuntime::Extension::Set.new([my_adds_instructions_ext])

    my_pipe = Pipeline([:a, :a], [:c, :c])

    new_node_attrs = my_set.(task: my_pipe, id: :my_pipe)

    expected_pipe_after_ext = Pipeline(
      [:a, :a],
      [:b, :b, Module],
      [:c, :c]
    )

    assert_equal new_node_attrs[:task], expected_pipe_after_ext
  end
end
