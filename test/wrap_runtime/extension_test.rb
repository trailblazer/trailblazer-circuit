require "test_helper"

class WrapRuntimeExtensionTest < Minitest::Spec
  it "Extension::Conditions evaluates to true if all conditions are met" do
    conditions = Trailblazer::Circuit::WrapRuntime::Extension::Conditions.new(
      [
        ->(value_1:, **) { value_1 },
        ->(value_2:, **) { value_2 },
      ]
    )

    assert_equal true, !! conditions.(value_1: true, value_2: true, rubbish: Object)
    assert_equal false, conditions.(value_1: true, value_2: false, rubbish: Object)
  end

  it "via Extension::Chain, the Extension#call receives the node_attrs" do
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

    my_set = Trailblazer::Circuit::WrapRuntime::Extension::Chain.new([my_ext_1, my_ext_2])

    new_node_attrs = my_set.(task: Object, id: :node, my_capture: {})

    assert_equal new_node_attrs, {
      :task=>Object, :id=>:node, :my_ext_1=>true, :my_capture=>{:my_ext_1=>{:task=>Object, :id=>:node}, :my_ext_2=>{:task=>Object, :id=>:node, :my_ext_1=>true}}, :my_ext_2=>true
    }
  end

  it "what" do
    skip "
??? should Extensions have access to flow_options, too? they do now!"
# ??? should Extensions have access to flow_options, too?
  end

  it "Extension::AddsInstruction applies changes to the passed node's circuit" do
    my_adds_ext = ->(*, id:, **) {
      [
        [:b, Trailblazer::Circuit::Node[:b, Module], :after, :a]
      ]
    }

    my_adds_instructions_ext = Trailblazer::Circuit::WrapRuntime.Extension(->(*) { true }, adds: my_adds_ext) # this is run by WrapRuntime::Runner

    my_set = Trailblazer::Circuit::WrapRuntime::Extension::Chain.new([my_adds_instructions_ext])

    my_pipe = Pipeline([:a, :a], [:c, :c])

    # FIXME: why isn't Chain expecting *args?
    *_args, circuit_options = my_set.(nil, nil, nil, node: Trailblazer::Circuit::Node[my_pipe, Trailblazer::Circuit::Processor], id: :my_pipe)

    expected_pipe_after_ext = Pipeline(
      [:a, :a],
      [:b, :b, Module],
      [:c, :c]
    )

    assert_equal circuit_options[:node][:task], expected_pipe_after_ext
  end
end
