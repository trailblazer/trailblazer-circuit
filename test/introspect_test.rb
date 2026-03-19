require "test_helper"

class IntrospectionTest < Minitest::Spec
  describe "Introspect.find_path" do
    def fixtures
      my_nested_pipe = Pipeline(
        [:d, :d],
        [:e, :e],
      )

      my_pipe = Pipeline(
        [:a, :a],
        [:b, my_nested_pipe, _A::Circuit::Processor],
        [:c, :c],
      )

      top_node = _A::Circuit::Node[:Create, my_pipe, _A::Circuit::Processor]

      return top_node, my_pipe, my_nested_pipe
    end

    it "root node" do
      top_node, _ = fixtures

      assert_equal _A::Circuit::Node::Introspect.find_path(top_node, []), nil
      # DISCUSS: do we need to cover this?
    end

    it "[:a]" do
      top_node, top_pipe = fixtures

      assert_equal _A::Circuit::Node::Introspect.find_path(top_node, [:a]), top_pipe.nodes[:a]
    end

    it "[:a, :e]" do
      top_node, _, my_nested_pipe = fixtures

      assert_equal _A::Circuit::Node::Introspect.find_path(top_node, [:b, :e]), my_nested_pipe.nodes[:e]
    end
  end
end
