require "test_helper"

class ConditionalResolverTest < Minitest::Spec
  it "can decide between two paths" do
    my_resolver = Trailblazer::Circuit::Resolver::Conditional.new([Object, Module], :a, :b)

    assert_equal my_resolver.fetch(Object), [:a, Object]
    assert_equal my_resolver.fetch(Module), [:a, Module]
    assert_equal my_resolver.fetch(nil), [:b, nil]
  end

  it "we can pass an alternative signal in fetch" do
    my_resolver = Trailblazer::Circuit::Resolver::Conditional.new([Object, Module], :a, :b)

    assert_equal my_resolver.fetch(Object, "my signal"), [:a, "my signal"]
    assert_equal my_resolver.fetch(nil, "my signal"), [:b, "my signal"]
  end

  it "Circuit integration" do
    my_exec_context = T.def_tasks(:a, :b, :c, success_signal: Right)


    # as a "representative benchmark circuit", i use something like a VariableMapping:::Conditional, a mix of pipe and decider.
    my_circuit = Trailblazer::Circuit::Builder.Circuit(
      [:a, my_exec_context.method(:a), lib_interface, connections: Trailblazer::Circuit::Resolver::Conditional.new([Object], :b, :c)],
      [:b, my_exec_context.method(:b), lib_interface, connections: Trailblazer::Circuit::Resolver::Fixed.new(:nil)],
      [:c, my_exec_context.method(:c), lib_interface, connections: Trailblazer::Circuit::Resolver::Fixed.new(:nil)],
    )

    assert_run my_circuit, terminus: Right, seq: [:a, :c]
    assert_run my_circuit, terminus: Right, seq: [:y, :a, :c], flow_options: {application_ctx: {seq: [:y], a: Left}}
    assert_run my_circuit, terminus: Right, seq: [:y, :a, :b], flow_options: {application_ctx: {seq: [:y], a: Object}}
  end
end
