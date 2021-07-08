require "test_helper"

class CircuitTest < Minitest::Spec
  Start   = ->((options, *args), *_circuit_options) { options[:start] = 1; ["to a", [options, *args]] }
  A       = ->((options, *args), *_circuit_options) { options[:a] = 2;     ["from a", [options, *args]] }
  B       = ->((options, *args), *_circuit_options) { options[:b] = 3;     ["from b", [options, *args]] }
  End     = ->((options, *args), *_circuit_options) { options[:_end] = 4;  ["the end", [options, *args]] }
  C       = ->((options, *args), *_circuit_options) { options[:c] = 6;     ["from c", [options, *args]] }

  it do
    map = {
      Start => {"to a" => A, "to b" => B},
      A     => {"from a" => B},
      B     => {"from b" => End}
    }

    circuit = Trailblazer::Activity::Circuit.new(map, [End], start_task: map.keys.first)

    ctx = {}

    last_signal, (ctx, i, j, *bla) = circuit.([ctx, 1, 2], task: Start)

    expect(ctx.inspect).must_equal %{{:start=>1, :a=>2, :b=>3, :_end=>4}}
    expect(last_signal).must_equal "the end"
    expect(i).must_equal 1
    expect(j).must_equal 2
    expect(bla).must_equal []

    # ---

    ctx = {}
    flow_options = {stack: []}

    last_signal, (ctx, i, j, *bla) = circuit.([ctx, flow_options, 2], task: Start, runner: MyRunner)

    expect(flow_options).must_equal(stack: [Start, A, B, End])
  end

  MyRunner = ->(task, args, **circuit_options) do
    MyTrace.(task, args, **circuit_options)

    task.(args, **circuit_options)
  end

  MyTrace = ->(task, (_options, flow_options), **_circuit_options) { flow_options[:stack] << task }

  let(:nestable) do
    nest_map = {
      Start => {"to a" => C},
      C     => {"from c" => End}
    }

    nest = Trailblazer::Activity::Circuit.new(nest_map, [End], start_task: nest_map.keys.first)

    # FIXME: FROM Activity#call
    nest_call = ->((options, flow_options, *args), **circuit_options) {
      nest.([options, flow_options, *args], **circuit_options.merge(task: Start))
    }

    nest_call
  end

  let(:outer) do
    outer_map = {
        Start => { "to a" => A, "to b" => B },
        A     => { "from a" => nestable },
        nestable  => { "the end" => B },
        B     => { "from b" => End}
    }

    Trailblazer::Activity::Circuit.new(outer_map, [End], start_task: outer_map.keys.first)
  end

  it "allows nesting circuits by using a nesting callable" do
    ctx = {}

    last_signal, (ctx, i, j, *bla) = outer.([ctx, {}, 2], task: Start)

    expect(ctx.inspect).must_equal %{{:start=>1, :a=>2, :c=>6, :_end=>4, :b=>3}}
    expect(last_signal).must_equal "the end"
    expect(i).must_equal({})
    expect(j).must_equal 2
    expect(bla).must_equal []
  end

  it "allows using a custom :runner" do
    ctx          = {}
    flow_options = {stack: [], runner: MyRunner}

    last_signal, (ctx, flow_options, j, *bla) = outer.([ctx, flow_options, 2], task: Start, runner: MyRunner)

    expect(ctx.inspect).must_equal %{{:start=>1, :a=>2, :c=>6, :_end=>4, :b=>3}}
    expect(last_signal).must_equal "the end"
    expect(flow_options).must_equal(stack: [Start, A, nestable, Start, C, End, B, End], runner: MyRunner)
    expect(j).must_equal 2
    expect(bla).must_equal []
  end

  let(:wicked_circuit) do
    map = {
      Start => {eureka: A},
      A     => {"from a" => End}
    }

    Trailblazer::Activity::Circuit.new(map, [End], start_task: Start)
  end

  it "throws an exception if any unknown signal is caught" do
    DummyActivity = Class.new(Trailblazer::Activity)

    exception = assert_raises Trailblazer::Activity::Circuit::IllegalSignalError do
      ctx = {}
      flow_options = {}
      circuit_options = {exec_context: DummyActivity.new(Hash.new)}

      wicked_circuit.([ctx, flow_options], **circuit_options)
    end

    message = "CircuitTest::DummyActivity: \n" \
      "\e[31mUnrecognized Signal `\"to a\"` returned from #{Start}. Registered signals are, \e[0m\n" \
      "\e[32m:eureka\e[0m"

    assert_equal message, exception.message

    assert_equal Start, exception.task
    assert_equal "to a", exception.signal
  end
end
