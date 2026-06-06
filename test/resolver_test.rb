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
end
