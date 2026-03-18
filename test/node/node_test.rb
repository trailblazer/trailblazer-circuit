require "test_helper"

class NodeTest < Minitest::Spec
  MyInterface = Class.new

  describe "Node.new" do
    it "raises if required keywords are missing" do
      exception = assert_raises ArgumentError do
        my_node = Trailblazer::Circuit::Node.new
      end

      assert_equal exception.message, %(missing keywords: :id, :task, :interface)
    end

    it "has required keywords" do
      my_node = Trailblazer::Circuit::Node.new(id: :a, task: :method_a, interface: MyInterface)

      assert_equal my_node.to_h, {
        :id=>:a,
        :task=>:method_a,
        :interface=>MyInterface
      }
    end
  end

# raise "where do we default things like interface, it's a very application-dependent thing"

  describe "Node[]" do
    it "raises if required arguments are missing" do
      exception = assert_raises ArgumentError do
        my_node = Trailblazer::Circuit::Node[]
      end

      assert_equal exception.message, %(wrong number of arguments (given 0, expected 3))
    end

    it "forwards to keyword version" do
      my_node = Trailblazer::Circuit::Node[:a, :method_a, MyInterface]

      assert_equal my_node.to_h, {
        :id=>:a,
        :task=>:method_a,
        :interface=>MyInterface
      }
    end
  end
end
