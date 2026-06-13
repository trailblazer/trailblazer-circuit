require "test_helper"

class ConditionalResolverTest < Minitest::Spec
  let(:my_resolver) { Trailblazer::Circuit::Resolver::Conditional.new([Object, Module], :a, :b) }

  it "can decide between two paths" do
    assert_equal my_resolver.fetch(Object), [:a, Object]
    assert_equal my_resolver.fetch(Module), [:a, Module]
    assert_equal my_resolver.fetch(nil), [:b, nil]

    assert_equal my_resolver.fetch(:Right), [:b, :Right] # DISCUSS: it always returns the signal, even when unknown.
  end

  it "we can pass an alternative signal in fetch" do
    my_resolver = Trailblazer::Circuit::Resolver::Conditional.new([Object, Module], :a, :b)

    assert_equal my_resolver.fetch(Object, "my signal"), [:a, "my signal"]
    assert_equal my_resolver.fetch(nil, "my signal"), [:b, "my signal"]
  end

  it "implements Adds interface" do
    assert_equal my_resolver.values, [[:a, Object], [:a, Module], [:b, nil]]

    # override existing
    my_new_resolver = my_resolver.merge(Object => [:c, Object])

    assert_equal my_new_resolver.values, [[:c, Object], [:b, nil]] # DISCUSS: override all known signals?
    assert_equal my_new_resolver.fetch(Object), [:c, Object]
    assert_equal my_new_resolver.fetch("anything"), [:b, "anything"]
  end

  describe "#merge" do
    let(:my_resolver) { Trailblazer::Circuit::Resolver::Conditional.new([:Left], :a, :b) }

    it "the known signal overrides an existing wiring" do
      # merge is usually (?) called when putting a node *after* a predessor. we cannot change the signals from this
      # predessor, so when i say "merge Left" i want to redirect the entire "known" route?
      merged_resolver = my_resolver.merge(:Left => [:c, :Left]) # DISCUSS: with a known signal, does that mean we want to override the entire path?

      assert_equal merged_resolver.fetch(:Left), [:c, :Left]
      assert_equal merged_resolver.fetch(:Right), [:b, :Right] # everything else still goes to fallback id.
    end

    it "fallback id can be set via merging {nil}" do
      merged_resolver = my_resolver.merge(nil => [:c, nil]) # DISCUSS: with a known signal, does that mean we want to override the entire path?

      assert_equal merged_resolver.fetch(:Left), [:a, :Left]
      assert_equal merged_resolver.fetch(:Right), [:c, :Right]
      assert_equal merged_resolver.fetch(nil), [:c, nil]
    end

    it "TODO: what do we do when there multiple known signals?" do

    end

    it "merge raises when unknown signal (?)" do
      # DISCUSS
      exception = assert_raises do
        my_resolver.merge(:Right => [:c, :Right])
      end

      assert_equal exception.message, "unknown outbound signal Right"
    end

    it "{#merge} creates copy for known signal merge" do
      my_new_resolver = my_resolver.merge(:Left => [:c, :Left])

      assert_equal my_resolver.values, [[:a, :Left], [:b, nil]]
      assert_equal my_new_resolver.values, [[:c, :Left], [:b, nil]]
    end

    it "{#merge} creates copy for the fallback merge" do
      my_new_resolver = my_resolver.merge(nil => [:c, nil])

      assert_equal my_resolver.values, [[:a, :Left], [:b, nil]]
      assert_equal my_new_resolver.values, [[:a, :Left], [:c, nil]]
    end
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

class FixedResolverTest < Minitest::Spec
  let(:my_resolver) { Trailblazer::Circuit::Resolver::Fixed.new(:a) }

  it "implements {#fetch} and always returns {:a} along with the resolved/queried signal" do
    assert_equal my_resolver.fetch(Object), [:a, Object]
    assert_equal my_resolver.fetch(nil), [:a, nil]
  end

  it "implements Adds interface: {#merge}" do
    my_new_resolver = my_resolver.merge(nil => [:b, nil])

    assert_equal my_resolver.values, [[:a, nil]]
    assert_equal my_new_resolver.values, [[:b, nil]]
  end
end
