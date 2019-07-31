require "test_helper"

class ActivityTest < Minitest::Spec
  it "provides {#inspect}" do
    Trailblazer::Activity.new({}).inspect.gsub(/0x\w+/, "0x").must_equal %{#<Trailblazer::Activity:0x>}
  end

  it "empty Activity" do
    skip
    activity = Module.new do
      extend Trailblazer::Activity::Path()
    end

    # puts Cct(activity.instance_variable_get(:@process))
    Cct(activity).must_equal %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>
}
  end

  it "can start with any task" do
    skip
    signal, (options, _) = activity.( [{}], start_task: L )

    signal.must_equal activity.outputs[:success].signal
    options.inspect.must_equal %{{:L=>1}}
  end

# TODO: test {to_h} properly
  it "exposes {:data} attributes in {#to_h}" do
    bc.to_h[:nodes][1][:data].inspect.must_equal %{{:additional=>true}}
  end

  it "{:activity}" do
    intermediate = Inter.new(
      {
        Inter::TaskRef(:a)  => [Inter::Out(:success, :b)],
        Inter::TaskRef(:b) => [Inter::Out(:success, :c)],
        Inter::TaskRef(:c) => [Inter::Out(:success, :d)],
        Inter::TaskRef(:d) => [Inter::Out(:success, nil)],
      },
      [:d],
      [:a] # start
    )

    track = ->((ctx, flow), circuit_options) { ctx += [circuit_options[:activity]]; [Activity::Right, [ctx, flow]] }

    implementation = {
      :a => Schema::Implementation::Task(track, [Activity::Output(Activity::Right, :success)], []),
      :b => Schema::Implementation::Task(track.clone, [Activity::Output(Activity::Right, :success)], []),
      :c => Schema::Implementation::Task(track.clone, [Activity::Output(Activity::Right, :success)], []),
      :d => Schema::Implementation::Task(track.clone, [Activity::Output(Activity::Right, :success)], []),
    }

    nested_activity = Activity.new(Inter.(intermediate, implementation))

    implementation = {
      :a => Schema::Implementation::Task(track, [Activity::Output(Activity::Right, :success)], []),
      :b => Schema::Implementation::Task(nested_activity, [Activity::Output(Activity::Right, :success)], []),
      :c => Schema::Implementation::Task(track.clone, [Activity::Output(Activity::Right, :success)], []),
      :d => Schema::Implementation::Task(track.clone, [Activity::Output(Activity::Right, :success)], []),
    }

    activity = Activity.new(Inter.(intermediate, implementation))

    signal, (ctx, _) = activity.([[], {}])

    # each task receives the containing {:activity}
    ctx.must_equal [activity, nested_activity, nested_activity, nested_activity, nested_activity, activity, activity]
  end
end
