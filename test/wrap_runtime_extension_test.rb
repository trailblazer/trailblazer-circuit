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

  it "Extension::AddsInstruction applies a" do

  end
end
