require "test_helper"

class NodeTest < Minitest::Spec
  MyInterface = Class.new
# raise "where do we default things like interface, it's a very application-dependent thing"

  describe "Node[]" do
    it "raises if required arguments are missing" do
      exception = assert_raises ArgumentError do
        my_node = Trailblazer::Circuit::Node[]
      end

      assert_equal exception.message, %(wrong number of arguments (given 0, expected 2))
    end

    it "defaults {options} to empty hash" do
      my_node = Trailblazer::Circuit::Node[:method_a, MyInterface]

      assert_equal my_node.to_h, {
        :task=>:method_a,
        :adapter=>MyInterface,
        :options=>{},
      }
    end

    it "discards keyword arguments" do
      my_node = Trailblazer::Circuit::Node[:method_a, MyInterface, **{}]

      assert_equal my_node.to_h, {
        :task=>:method_a,
        :adapter=>MyInterface,
        :options=>{},
      }
    end
  end

  describe "Node#merge" do
    let(:my_node) { Trailblazer::Circuit::Node[:a, MyInterface, options: {important: true}] }

    it "copies all properties and keeps the class, creating a second instance" do
      my_copy = my_node.merge(options: {data: 1})

      assert_equal my_node, Trailblazer::Circuit::Node[:a, MyInterface, options: {important: true}]
      assert_equal my_copy, Trailblazer::Circuit::Node[:a, MyInterface, options: {important: true, data: 1}]
    end

    it "accepts all properties as kwargs, they simply override their original, expect for {:options}" do
      my_copy = my_node.merge(task: :b, adapter: Object, options: {data: 1})

      assert_equal my_node, Trailblazer::Circuit::Node[:a, MyInterface, options: {important: true}]
      assert_equal my_copy, Trailblazer::Circuit::Node[:b, Object, options: {important: true, data: 1}]
    end
  end
end
