require "test_helper"

class NodeScopedTest < Minitest::Spec
  MyInterface = Class.new

  describe "Node::Scoped.new" do
    it "raises if required keywords are missing" do
      exception = assert_raises ArgumentError do
        my_node = Trailblazer::Circuit::Node::Scoped.new
      end

      assert_equal exception.message, %(missing keywords: :id, :task, :interface)
    end

    it "has required keywords, defaults the rest" do
      my_node = Trailblazer::Circuit::Node::Scoped.new(id: :a, task: :method_a, interface: MyInterface)

      assert_equal my_node.to_h, {
        :id=>:a,
        :task=>:method_a,
        :interface=>MyInterface,
        :merge_to_lib_ctx=>{},
        :copy_from_outer_ctx=>nil,
        :copy_to_outer_ctx=>[],
        :return_outer_signal=>false
      }
    end

    it "accepts all keywords explicitly" do
      my_node = Trailblazer::Circuit::Node::Scoped.new(
        id: :a,
        task: :method_a,
        interface: MyInterface,
        merge_to_lib_ctx: {value: {}},
        copy_from_outer_ctx: [:a],
        copy_to_outer_ctx: [:b],
        return_outer_signal: true
      )

      assert_equal my_node.to_h, {
        :id=>:a,
        :task=>:method_a,
        :interface=>MyInterface,
        :merge_to_lib_ctx=>{value: {}},
        :copy_from_outer_ctx=>[:a],
        :copy_to_outer_ctx=>[:b],
        :return_outer_signal=>true
      }
    end
  end

  describe "Node::Scope[]" do
    it "raises if required arguments are missing" do
      exception = assert_raises ArgumentError do
        my_node = Trailblazer::Circuit::Node::Scoped[]
      end

      assert_equal exception.message, %(wrong number of arguments (given 0, expected 3))
    end

    it "forwards to keyword version" do
      my_node = Trailblazer::Circuit::Node::Scoped[:a, :method_a, MyInterface]

      assert_equal my_node.to_h, {
        :id=>:a,
        :task=>:method_a,
        :interface=>MyInterface,
        :merge_to_lib_ctx=>{},
        :copy_from_outer_ctx=>nil,
        :copy_to_outer_ctx=>[],
        :return_outer_signal=>false
      }
    end

    it "raises when passing a fourth positional arg. this is for safety reasons" do
      assert_raises ArgumentError do
        my_node = Trailblazer::Circuit::Node::Scoped[
          :a,
          :method_a,
          MyInterface,
          {exec_context: Object} # an explicit hash here is {merge_to_lib_ctx}, but it's invalid.
        ]
      end
    end

    it "allows to pass the complicated kwargs after the three positionals" do
      my_node = Trailblazer::Circuit::Node::Scoped[:a, :method_a, MyInterface, merge_to_lib_ctx: {exec_context: Object}, return_outer_signal: true]

      assert_equal my_node.to_h, {
        :id=>:a,
        :task=>:method_a,
        :interface=>MyInterface,
        :merge_to_lib_ctx=>{exec_context: Object},
        :copy_from_outer_ctx=>nil,
        :copy_to_outer_ctx=>[],
        :return_outer_signal=>true
      }
    end
  end

  # it "{#to_h}" do
  #   # this is currently tested implicitely above :D
  # end
end
