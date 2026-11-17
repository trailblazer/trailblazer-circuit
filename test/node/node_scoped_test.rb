require "test_helper"

class NodeScopedTest < Minitest::Spec
  MyInterface = Class.new

  describe "Node::Scope[]" do
    it "raises if required arguments are missing" do
      exception = assert_raises ArgumentError do
        my_node = Trailblazer::Circuit::Node::Scoped[]
      end

      assert_equal exception.message, %(wrong number of arguments (given 0, expected 2))
    end

    it "defaults" do
      my_node = Trailblazer::Circuit::Node::Scoped[:method_a, MyInterface]

      assert_equal my_node.to_h, {
        :task=>:method_a,
        :interface=>MyInterface,
        :options=>{},
        :merge_to_lib_ctx=>{},
        :copy_from_outer_ctx=>nil,
        :copy_to_outer_ctx=>[],
        :return_outer_signal=>false
      }
    end

    it "accepts scoping keywords explicitly" do
      options = {
        merge_to_lib_ctx: {value: {}},
        copy_from_outer_ctx: [:a],
        copy_to_outer_ctx: [:b],
        return_outer_signal: true
      }

      my_node = Trailblazer::Circuit::Node::Scoped[
        :method_a,
        MyInterface,
        **options
      ]

      assert_equal my_node.to_h, {
        :task=>:method_a,
        :interface=>MyInterface,
        :options=>{},
        **options
      }
    end
  end

  describe "Node#merge" do
    it "copies all properties and keeps the class, creating a second instance" do
      my_node = Trailblazer::Circuit::Node::Scoped[:a, "MyInterface", copy_from_outer_ctx: [:model]]
      my_copy = my_node.merge(options: {business: true})

      assert_equal my_node, Trailblazer::Circuit::Node::Scoped[:a, "MyInterface", options: {}, copy_from_outer_ctx: [:model]]
      assert_equal my_copy, Trailblazer::Circuit::Node::Scoped[:a, "MyInterface", options: {business: true}, copy_from_outer_ctx: [:model]]
    end
  end

  # it "{#to_h}" do
  #   # this is currently tested implicitely above :D
  # end
end
