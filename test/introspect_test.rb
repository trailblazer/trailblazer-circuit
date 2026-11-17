require "test_helper"

class IntrospectionTest < Minitest::Spec
  def fixtures
    my_g_pipe = Pipeline(
      [:g, :g, options: {important: true}],
    )

    my_nested_pipe = Pipeline(
      [:d, :d],
      [:e, :e, options: {important: true}],
      [:f, my_g_pipe, Trailblazer::Circuit::Processor]
    )

    top_node = Trailblazer::Circuit.Builder(
      [:a, :a],
      [:b, my_nested_pipe, _A::Circuit::Processor],
      [:c, :c],
    )

    return top_node, my_nested_pipe, my_g_pipe
  end

  describe "Introspect.find" do
    it "one level" do
      top_node, _ = fixtures()
      nodes = Trailblazer::Circuit::Node::Introspect.find(top_node) { |id, node| id == :c }

      # path => node
      assert_equal nodes, [
        [[:c], top_node.task.nodes.fetch(:c)]
      ]
    end

    it "three levels" do
      top_node, _, my_g_pipe = fixtures()
      nodes = Trailblazer::Circuit::Node::Introspect.find(top_node) { |id, node| id == :g }

      # path => node
      assert_equal nodes, [
        [[:b, :f, :g], my_g_pipe.nodes.fetch(:g)]
      ]
    end

    it "block receives id and node instance" do
      top_node, my_nested_pipe, my_g_pipe = fixtures()

      nodes = Trailblazer::Circuit::Node::Introspect.find(top_node) { |id, node| node.options[:important] }

      assert_equal nodes, [
        [[:b, :e], my_nested_pipe.nodes.fetch(:e)],
        [[:b, :f, :g], my_g_pipe.nodes.fetch(:g)],
      ]
    end
  end

  describe "Introspect.find_path" do
    it "root node" do
      top_node, _ = fixtures()

      assert_equal _A::Circuit::Node::Introspect.find_path(top_node, []), nil
      # DISCUSS: do we need to cover this?
    end

    it "[:a]" do
      top_node, _ = fixtures()

      assert_equal _A::Circuit::Node::Introspect.find_path(top_node, [:a]), top_node.task.nodes[:a]
    end

    it "[:a, :e]" do
      top_node, my_nested_pipe = fixtures()

      assert_equal _A::Circuit::Node::Introspect.find_path(top_node, [:b, :e]), my_nested_pipe.nodes[:e]
    end
  end
end
